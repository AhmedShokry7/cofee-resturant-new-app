part of 'favorites_cubit.dart';

@immutable
class FavoritesState {
  const FavoritesState({
    required this.ids,
    this.products = const {},
    this.isLoading = true,
    this.error,
  });

  final Set<String> ids;

  /// Resolved catalogue rows. A stored id that no longer exists has no entry
  /// and is therefore omitted from the grid rather than shown as stale data.
  final Map<String, ProductModel> products;

  final bool isLoading;
  final String? error;

  List<ProductModel> get favoriteProducts => [
        for (final id in ids)
          if (products[id] != null) products[id]!,
      ];

  bool get isEmpty => !isLoading && favoriteProducts.isEmpty;

  FavoritesState copyWith({
    Set<String>? ids,
    Map<String, ProductModel>? products,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      FavoritesState(
        ids: ids ?? this.ids,
        products: products ?? this.products,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}
