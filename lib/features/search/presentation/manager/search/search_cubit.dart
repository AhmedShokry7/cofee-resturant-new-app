import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/search/data/model/search_sort.dart';

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
  })  : _catalog = catalogRepository,
        super(
          const SearchState(
            query: "",
            sort: SearchSort.relevance,
            results: [],
          ),
        ) {
    loadInitial();
  }

final CatalogRepository _catalog;

  /// Branch whose prices and availability apply to these results.
  final String? branchId;

  /// Overrides [branchId] once the customer picks a different branch.
  String? _branchIdOverride;

  String? get _effectiveBranch => _branchIdOverride ?? branchId;

  Future<void> loadInitial() async {
    // Loaded once so the filter sheet has real category ids to send. Kept out
    // of _run so changing the sort or the price range does not refetch the list.
    var categories = state.categories;
    try {
      categories = await _catalog.getCategories();
    } catch (error, stackTrace) {
      // A missing category list must not block searching.
      addError(error, stackTrace);
    }
    return _run(query: state.query, categories: categories);
  }

  void search(String query) => _run(query: query);

  void applyFilters({
    required SearchSort sort,
    String? category,
    double? minPrice,
    double? maxPrice,
  }) =>
      _run(
        query: state.query,
        sort: sort,
        category: category,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );

  void resetFilters() => _run(
        query: state.query,
        sort: SearchSort.relevance,
        category: null,
        minPrice: null,
        maxPrice: null,
      );

  /// Switches the branch the results are priced for, and re-runs the query.
  void setBranch(String? branchId) {
    _branchIdOverride = branchId;
    _run(query: state.query);
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
    emit(SearchState(
      query: query,
      sort: sort ?? state.sort,
      categories: categories ?? state.categories,
      category: category,
      minPrice: minPrice,
      maxPrice: maxPrice,
      results: state.results,
      isLoading: true,
    ));

    try {
      var results = await _catalog.search(
        query,
        branchId: _effectiveBranch,
        categoryId: category,
        sort: _sortCode(sort ?? state.sort),
        limit: 100,
      );

      // Price filtering stays client-side because the RPC deliberately keeps
      // its signature small. The result set here is one page of at most 100,
      // so this is cheap and keeps the range slider responsive.
      results = results.where((p) {
        if (minPrice != null && p.price < minPrice) return false;
        if (maxPrice != null && p.price > maxPrice) return false;
        return true;
      }).toList();

emit(SearchState(
        query: query,
        sort: sort ?? state.sort,
        categories: categories ?? state.categories,
        category: category,
        minPrice: minPrice,
        maxPrice: maxPrice,
        results: results,
      ));
    } catch (error, stackTrace) {
      emit(SearchState(
        query: query,
        sort: sort ?? state.sort,
        categories: categories ?? state.categories,
        category: category,
        minPrice: minPrice,
        maxPrice: maxPrice,
        results: const [],
        error: error.toString(),
      ));
      addError(error, stackTrace);
    }
  }

  static String _sortCode(SearchSort sort) {
    switch (sort) {
      case SearchSort.priceLowHigh:
        return 'priceLowHigh';
      case SearchSort.priceHighLow:
        return 'priceHighLow';
      case SearchSort.nameAsc:
        return 'nameAsc';
      case SearchSort.relevance:
        return 'relevance';
    }
  }
}