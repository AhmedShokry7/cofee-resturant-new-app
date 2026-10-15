part of 'home_cubit.dart';

@immutable
class HomeState {
  const HomeState({
    this.banners = const [],
    this.bundles = const [],
    this.categories = const [],
    this.popular = const [],
    this.recommendationPool = const [],
    this.bundleProducts = const {},
    this.isLoading = true,
    this.error,
  });

  final List<BannerModel> banners;
  final List<BundleModel> bundles;
  final List<CategoryModel> categories;

  /// Featured products: admin-pinned first, then best sellers.
  final List<ProductModel> popular;

  /// Candidate pool the recommendation rule filters. Loaded once so a weather
  /// change never triggers a query.
  final List<ProductModel> recommendationPool;

  /// Products contained by the loaded bundles, keyed by product id.
  final Map<String, ProductModel> bundleProducts;

  final bool isLoading;

  /// Set when a source failed. Individual sections keep whatever they had, so
  /// the page degrades instead of going blank.
  final String? error;

  /// True before anything has ever loaded, which is different from loaded and
  /// found nothing.
  bool get isFirstLoad => isLoading && banners.isEmpty && bundles.isEmpty;

  /// Banners past the carousel, used by the single promo banner slot.
  BannerModel? get promoBanner {
    if (banners.length < 2) return null;
    return banners[1];
  }

  /// Products a banner points at, resolved by the banner's typed target.
  ///
  /// Replaces the old lookup that compared products to a raw category name
  /// string, which broke whenever a category was renamed.
  List<ProductModel> productsForBanner(BannerModel banner) {
    if (banner.targetType != 'category' || banner.targetId == null) {
      return const [];
    }
    final id = banner.targetId;
    return recommendationPool
        .where((p) => p.categoryId == id)
        .toList(growable: false);
  }

  HomeState copyWith({
    List<BannerModel>? banners,
    List<BundleModel>? bundles,
    List<CategoryModel>? categories,
    List<ProductModel>? popular,
    List<ProductModel>? recommendationPool,
    Map<String, ProductModel>? bundleProducts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      HomeState(
        banners: banners ?? this.banners,
        bundles: bundles ?? this.bundles,
        categories: categories ?? this.categories,
        popular: popular ?? this.popular,
        recommendationPool: recommendationPool ?? this.recommendationPool,
        bundleProducts: bundleProducts ?? this.bundleProducts,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}