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
  bool get isFirstLoad =>
      isLoading &&
      banners.isEmpty &&
      bundles.isEmpty &&
      categories.isEmpty &&
      popular.isEmpty &&
      recommendationPool.isEmpty;

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
    switch (banner.target) {
      case BannerTarget.product:
        final product = banner.targetProduct;
        if (product != null) return [product];
        // Fall back to the pool when the target was not resolved.
        final id = banner.targetId;
        if (id == null) return const [];
        return recommendationPool
            .where((p) => p.id == id)
            .toList(growable: false);
      case BannerTarget.bundle:
        final bundle = banner.targetBundle;
        if (bundle == null) return const [];
        return [
          for (final c in bundle.components)
            if (bundleProducts[c.productId] != null)
              bundleProducts[c.productId]!,
        ];
      case BannerTarget.category:
        final id = banner.targetId;
        if (id == null) return const [];
        return recommendationPool
            .where((p) => p.categoryId == id)
            .toList(growable: false);
      default:
        return const [];
    }
  }

  /// Category slugs that suit a hot day, and those that suit a cold one.
  ///
  /// Slugs, not display names: renaming a category must not silently break the
  /// rule, which is what happened when this matched on English strings.
  static const Set<String> hotDayCategorySlugs = {
    'cold-coffee',
    'soft-drinks',
    'milkshakes',
  };
  static const Set<String> coldDayCategorySlugs = {'hot-coffee', 'tea'};

  /// How many rows the recommendations strip shows.
  static const int maxRecommendations = 4;

  /// The [recommendationPool] ordered for the customer: something they
  /// favourited first, then whatever the weather suggests, then menu order.
  ///
  /// The home widget used to rank this during build, so the rule could not be
  /// tested and was re-run on every frame.
  List<ProductModel> recommendations({
    WeatherModel? weather,
    Set<String> favoriteIds = const {},
  }) {
    final seasonalSlugs = weather == null
        ? const <String>{}
        : weather.isHot
        ? hotDayCategorySlugs
        : coldDayCategorySlugs;
    int score(ProductModel product) =>
        (favoriteIds.contains(product.id) ? 2 : 0) +
        (weather != null && seasonalSlugs.contains(product.categorySlug)
            ? 1
            : 0);
    final ranked = recommendationPool.indexed.toList()
      ..sort((a, b) {
        final byScore = score(b.$2).compareTo(score(a.$2));
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });
    return ranked
        .take(maxRecommendations)
        .map((entry) => entry.$2)
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
  }) => HomeState(
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
