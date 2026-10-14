part of 'search_cubit.dart';

@immutable
class SearchState {
  const SearchState({
    required this.query,
    required this.sort,
    this.category,
    this.minPrice,
    this.maxPrice,
    required this.results,
  });

  final String query;
  final SearchSort sort;
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final List<ProductModel> results;

  bool get hasActiveFilters =>
      sort != SearchSort.relevance || category != null || minPrice != null;
}
