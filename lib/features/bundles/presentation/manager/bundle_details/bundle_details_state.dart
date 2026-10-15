part of 'bundle_details_cubit.dart';

@immutable
class BundleDetailsState {
  const BundleDetailsState({
    required this.bundle,
    this.products = const [],
    this.productsById = const {},
    this.isLoading = true,
    this.error,
  });

  final BundleModel bundle;
  final List<ProductModel> products;
  final Map<String, ProductModel> productsById;
  final bool isLoading;
  final String? error;

  BundleDetailsState copyWith({
    List<ProductModel>? products,
    Map<String, ProductModel>? productsById,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      BundleDetailsState(
        bundle: bundle,
        products: products ?? this.products,
        productsById: productsById ?? this.productsById,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}
