part of 'search_cubit.dart';

@immutable
class SearchState {
  const SearchState({
    required this.query,
    required this.sort,
    required this.results,
    this.categories = const [],
    this.category,
    this.minPrice,
    this.maxPrice,
    this.isLoading = false,
    this.error,
  });

  final String query;
  final SearchSort sort;

  /// Categories offered by the filter sheet.
  ///
  /// They live in the state rather than as a field on the cubit so the sheet
  /// rebuilds when they arrive. The sheet used to build its chips from a Dart
  /// constant list, which meant a category added in the admin panel could never
  /// be filtered on, and it sent the chosen chip's display label through as
  /// `categoryId` so the filter matched nothing at all.
  final List<CategoryModel> categories;

  /// Selected category **id**, not a label.
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final List<ProductModel> results;

  /// True while a query is in flight. The previous page showed stale results
  /// with no indication anything was happening.
  final bool isLoading;

  /// Non-null when the search failed. The message is shown instead of an empty
  /// list, so an outage never looks like "no results".
  final String? error;

  bool get hasActiveFilters =>
      sort != SearchSort.relevance ||
      category != null ||
      minPrice != null ||
      maxPrice != null;

  /// True when a search ran and legitimately found nothing.
  bool get isEmptyResult => !isLoading && error == null && results.isEmpty;
}