part of 'search_cubit.dart';

@immutable
class SearchState {
  const SearchState({required this.query, required this.results});

  final String query;
  final List<ProductModel> results;
}
