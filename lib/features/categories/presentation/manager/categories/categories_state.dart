part of 'categories_cubit.dart';

@immutable
class CategoriesState {
  const CategoriesState({
    this.categories = const [],
    this.products = const [],
    this.bundles = const [],
    this.index = 0,
    this.isLoading = true,
    this.error,
  });

  final List<CategoryModel> categories;

  /// Products for every category, loaded once. Filtering per tab is cheaper
  /// than one query per tab, and tabs are switched constantly.
  final List<ProductModel> products;

  final List<BundleModel> bundles;

  final int index;

  final bool isLoading;
  final String? error;

  bool get isEmpty => !isLoading && categories.isEmpty;

  CategoriesState copyWith({
    List<CategoryModel>? categories,
    List<ProductModel>? products,
    List<BundleModel>? bundles,
    int? index,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => CategoriesState(
    categories: categories ?? this.categories,
    products: products ?? this.products,
    bundles: bundles ?? this.bundles,
    index: index ?? this.index,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}
