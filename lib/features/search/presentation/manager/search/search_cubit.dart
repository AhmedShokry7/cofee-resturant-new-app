import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/di/branch_cubit_binding.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/search/data/model/search_sort.dart';
import 'package:new_coffee/shared/utils/rate_limit_client.dart';

part 'search_state.dart';

/// Search now runs in the database.
///
/// Before this change the cubit filtered a Dart constant list in memory and
/// borrowed the assistant's Arabic synonym map to make any Arabic query work at
/// all (search_cubit.dart imported AssistantPhrases and getMenuList). Both
/// aliases and normalisation now live in Postgres, so this cubit holds no
/// vocabulary and loads no catalogue of its own.
class SearchCubit extends Cubit<SearchState> {
  SearchCubit({
    required CatalogRepository catalogRepository,
    required this.branchId,
    BranchCubit? branchCubit,
  }) : _catalog = catalogRepository,
       super(
         const SearchState(query: "", sort: SearchSort.relevance, results: []),
       ) {
    if (branchCubit != null) _branchBinding.bind(branchCubit, setBranch);
    loadInitial();
  }

  final CatalogRepository _catalog;
  final BranchCubitBinding _branchBinding = BranchCubitBinding();

  /// Branch whose prices and availability apply to these results.
  final String? branchId;

  /// Overrides [branchId] once the customer picks a different branch.
  String? _branchIdOverride;

  String? get _effectiveBranch => _branchIdOverride ?? branchId;

  /// How long typing must pause before a query is sent.
  ///
  /// Typing fires [search] on every character. Without this pause a six letter
  /// word costs six catalogue queries, and only the last one is ever wanted.
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  /// Pending debounced query, if the customer is still typing.
  Timer? _debounce;

  /// Latest query the customer asked for, including one still waiting on the
  /// debounce.
  ///
  /// [SearchState.query] only advances once [_run] emits, so during the pause it
  /// still holds the previous word. Filter and branch changes read this instead,
  /// so they never re-run a query the customer has already replaced.
  String _latestQuery = '';

  /// Unfiltered results for the current query and branch. Category, price and
  /// sort controls operate on this in-memory snapshot, so changing filters does
  /// not issue another catalogue request.
  List<ProductModel> _queryResults = const [];
  String? _loadedResultKey;

  /// Monotonic id of the newest search. Only the run holding the latest number
  /// may write state.
  ///
  /// Answers come back out of order: a slow early query must not overwrite a
  /// newer one, and a result for a query the customer has since cleared must
  /// never come back. Clearing the field bumps this too.
  int _searchGeneration = 0;

  Future<void> loadInitial() async {
    // Loaded once so the filter sheet has real category ids to send. No
    // search runs here: firing a catalogue-wide query just to show an idle
    // prompt would flash a spinner and waste a round trip on every open.
    var categories = state.categories;
    try {
      categories = await _catalog.getCategories();
    } catch (error, stackTrace) {
      // A missing category list must not block searching.
      addError(error, stackTrace);
    }
    if (isClosed) return;
    emit(
      SearchState(
        query: '',
        sort: state.sort,
        results: const [],
        categories: categories,
      ),
    );
  }

  /// Drops a keystroke that is still inside the pause.
  ///
  /// Every other entry point uses this. A filter applied while a word is still
  /// pending would otherwise be undone: the pause would fire afterwards and
  /// re-run the same query with no category and no price range, silently
  /// clearing what the customer just chose.
  void _cancelPendingQuery() {
    _debounce?.cancel();
    _debounce = null;
  }

  /// Clearing the field returns to the idle prompt instead of firing an
  /// empty query whose blank result would read as "no results".
  ///
  /// The reset is synchronous, as it has always been, and it also invalidates
  /// anything still in flight: a pending keystroke is dropped and a query that
  /// already reached the database can no longer put its results back.
  void search(String query) {
    _latestQuery = query;
    _cancelPendingQuery();
    if (query.trim().isEmpty) {
      _searchGeneration++;
      emit(
        SearchState(
          query: '',
          sort: state.sort,
          categories: state.categories,
          results: const [],
        ),
      );
      return;
    }
    _debounce = Timer(_debounceDelay, () {
      _debounce = null;
      if (isClosed) return;
      _run(query: query);
    });
  }

  void applyFilters({
    required SearchSort sort,
    String? category,
    double? minPrice,
    double? maxPrice,
  }) {
    _cancelPendingQuery();
    _run(
      query: _latestQuery,
      sort: sort,
      category: category,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
  }

  void resetFilters() {
    _cancelPendingQuery();
    _run(
      query: _latestQuery,
      sort: SearchSort.relevance,
      category: null,
      minPrice: null,
      maxPrice: null,
    );
  }

  /// Switches the branch the results are priced for, and re-runs the query.
  ///
  /// Deliberately not debounced: a branch change is a deliberate act on a
  /// settled query, and the price and availability of every result just
  /// changed, so it must refresh straight away rather than after a pause. The
  /// pause is dropped rather than left to fire later, because it would re-run
  /// the same query a second time.
  Future<void> setBranch(String? branchId) {
    _cancelPendingQuery();
    _branchIdOverride = branchId;
    return _run(query: _latestQuery);
  }

  /// Price bounds for the filter sheet, taken from what is actually loaded
  /// instead of scanning the whole catalogue.
  List<double> priceBounds() {
    final prices = state.results.map((p) => p.price).toList()..sort();
    if (prices.isEmpty) return const [0, 0];
    return [prices.first, prices.last];
  }

  Future<void> _run({
    required String query,
    SearchSort? sort,
    String? category,
    double? minPrice,
    double? maxPrice,
    List<CategoryModel>? categories,
  }) async {
    final generation = ++_searchGeneration;
    final effectiveSort = sort ?? state.sort;
    emit(
      SearchState(
        query: query,
        sort: effectiveSort,
        categories: categories ?? state.categories,
        category: category,
        minPrice: minPrice,
        maxPrice: maxPrice,
        results: state.results,
        isLoading: true,
        hasSearched: true,
      ),
    );

    try {
      final key = '${_effectiveBranch ?? ''}|${query.trim().toLowerCase()}';
      if (_loadedResultKey != key) {
        final allowed = await RateLimitClient().check('search');
        if (isClosed || generation != _searchGeneration) return;
        if (!allowed) {
          emit(
            SearchState(
              query: query,
              sort: effectiveSort,
              categories: categories ?? state.categories,
              category: category,
              minPrice: minPrice,
              maxPrice: maxPrice,
              results: const [],
              error: 'search rate limit exceeded',
              hasSearched: true,
            ),
          );
          return;
        }
        _queryResults = await _catalog.search(
          query,
          branchId: _effectiveBranch,
          sort: 'relevance',
          limit: 100,
        );
        _loadedResultKey = key;
      }
      if (isClosed) return;
      // A newer search owns the state now. This answer is discarded rather than
      // cancelling the request that is already on the wire.
      if (generation != _searchGeneration) return;

      // All filters stay local to the loaded result page. The selected category
      // and sort mode are presentation choices; they do not change the search
      // document being searched on the server.
      var results = _queryResults.where((p) {
        if (category != null && p.categoryId != category) return false;
        if (minPrice != null && p.price < minPrice) return false;
        if (maxPrice != null && p.price > maxPrice) return false;
        return true;
      }).toList();
      switch (effectiveSort) {
        case SearchSort.priceLowHigh:
          results.sort((a, b) => a.price.compareTo(b.price));
        case SearchSort.priceHighLow:
          results.sort((a, b) => b.price.compareTo(a.price));
        case SearchSort.nameAsc:
          results.sort((a, b) => a.name.compareTo(b.name));
        case SearchSort.relevance:
          break;
      }
      if (isClosed) return;
      if (generation != _searchGeneration) return;
      emit(
        SearchState(
          query: query,
          sort: effectiveSort,
          categories: categories ?? state.categories,
          category: category,
          minPrice: minPrice,
          maxPrice: maxPrice,
          results: results,
          hasSearched: true,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      // Same rule for failures: a stale error must not replace a newer result,
      // and it must not drop the customer back to "no results".
      if (generation != _searchGeneration) return;
      emit(
        SearchState(
          query: query,
          sort: effectiveSort,
          categories: categories ?? state.categories,
          category: category,
          minPrice: minPrice,
          maxPrice: maxPrice,
          results: const [],
          error: error.toString(),
          hasSearched: true,
        ),
      );
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    // Nothing may fire after the page is gone.
    _debounce?.cancel();
    _debounce = null;
    _queryResults = const [];
    await _branchBinding.close();
    await super.close();
  }
}
