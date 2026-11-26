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

  /// Current server page set. Filters and sort are sent to the search RPC so
  /// pagination covers matching products, not just the first page.
  List<ProductModel> _queryResults = const [];
  String? _loadedResultKey;
  int _nextOffset = 0;
  bool _hasMoreResults = false;

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

  /// Fetches the next server page for the current query. The list view calls
  /// this near its end; results already loaded remain visible while it runs.
  Future<void> loadMore() async {
    final current = state;
    if (isClosed ||
        current.isLoading ||
        current.isLoadingMore ||
        !_hasMoreResults ||
        current.query.trim().isEmpty) {
      return;
    }
    final generation = _searchGeneration;
    emit(_copyState(current, isLoadingMore: true));
    try {
      final page = await _catalog.search(
        current.query,
        branchId: _effectiveBranch,
        categoryId: current.category,
        minPrice: current.minPrice,
        maxPrice: current.maxPrice,
        sort: _serverSort(current.sort),
        limit: 100,
        offset: _nextOffset,
      );
      if (isClosed || generation != _searchGeneration) return;
      _nextOffset += page.length;
      _hasMoreResults = page.length == 100;
      _queryResults = [..._queryResults, ...page];
      emit(
        _copyState(
          current,
          results: _visibleResults(
            _queryResults,
            category: current.category,
            minPrice: current.minPrice,
            maxPrice: current.maxPrice,
            sort: current.sort,
          ),
          isLoadingMore: false,
          hasMore: _hasMoreResults,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != _searchGeneration) return;
      emit(_copyState(current, isLoadingMore: false, error: error.toString()));
      addError(error, stackTrace);
    }
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
      final key = [
        _effectiveBranch ?? '',
        query.trim().toLowerCase(),
        category ?? '',
        minPrice?.toString() ?? '',
        maxPrice?.toString() ?? '',
        effectiveSort.name,
      ].join('|');
      if (_loadedResultKey != key) {
        _queryResults = const [];
        _nextOffset = 0;
        _hasMoreResults = false;
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
          categoryId: category,
          minPrice: minPrice,
          maxPrice: maxPrice,
          sort: _serverSort(effectiveSort),
          limit: 100,
          offset: 0,
        );
        _nextOffset = _queryResults.length;
        _hasMoreResults = _queryResults.length == 100;
        _loadedResultKey = key;
      }
      if (isClosed) return;
      // A newer search owns the state now. This answer is discarded rather than
      // cancelling the request that is already on the wire.
      if (generation != _searchGeneration) return;

      // Keep a local guard as well so preview repositories and cached data
      // still obey the current filter state.
      final results = _visibleResults(
        _queryResults,
        category: category,
        minPrice: minPrice,
        maxPrice: maxPrice,
        sort: effectiveSort,
      );
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
          hasMore: _hasMoreResults,
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

  static String _serverSort(SearchSort sort) => switch (sort) {
    SearchSort.priceLowHigh => 'priceLowHigh',
    SearchSort.priceHighLow => 'priceHighLow',
    SearchSort.nameAsc => 'nameAsc',
    SearchSort.relevance => 'relevance',
  };

  static List<ProductModel> _visibleResults(
    List<ProductModel> source, {
    required String? category,
    required double? minPrice,
    required double? maxPrice,
    required SearchSort sort,
  }) {
    final results = source.where((p) {
      if (category != null && p.categoryId != category) return false;
      if (minPrice != null && p.price < minPrice) return false;
      if (maxPrice != null && p.price > maxPrice) return false;
      return true;
    }).toList();
    switch (sort) {
      case SearchSort.priceLowHigh:
        results.sort((a, b) => a.price.compareTo(b.price));
      case SearchSort.priceHighLow:
        results.sort((a, b) => b.price.compareTo(a.price));
      case SearchSort.nameAsc:
        results.sort((a, b) => a.name.compareTo(b.name));
      case SearchSort.relevance:
        break;
    }
    return results;
  }

  SearchState _copyState(
    SearchState source, {
    List<ProductModel>? results,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) => SearchState(
    query: source.query,
    sort: source.sort,
    categories: source.categories,
    category: source.category,
    minPrice: source.minPrice,
    maxPrice: source.maxPrice,
    results: results ?? source.results,
    isLoading: source.isLoading,
    isLoadingMore: isLoadingMore ?? source.isLoadingMore,
    hasMore: hasMore ?? source.hasMore,
    error: error,
    hasSearched: source.hasSearched,
  );

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
