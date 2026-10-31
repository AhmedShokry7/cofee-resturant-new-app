part of 'bundle_details_cubit.dart';

@immutable
class BundleDetailsState {
  const BundleDetailsState({
    required this.bundle,
    this.products = const [],
    this.productsById = const {},
    this.pairs = const [],
    this.isLoading = true,
    this.error,
  });

  final BundleModel bundle;
  final List<ProductModel> products;
  final Map<String, ProductModel> productsById;

  /// Non-member products sharing a category with the bundle contents, resolved
  /// by one bounded page read once the price breakdown is on screen. The bundle
  /// page deliberately shows no carousel — cross-sell belongs to product
  /// details — so nothing here renders them today.
  final List<ProductModel> pairs;
  final bool isLoading;
  final String? error;

  BundleDetailsState copyWith({
    List<ProductModel>? products,
    Map<String, ProductModel>? productsById,
    List<ProductModel>? pairs,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => BundleDetailsState(
    bundle: bundle,
    products: products ?? this.products,
    productsById: productsById ?? this.productsById,
    pairs: pairs ?? this.pairs,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}
