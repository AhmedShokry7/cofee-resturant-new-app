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
    this.degradedSections = const [],
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

  /// The sections whose source failed on the load that produced this state.
  /// Machine names, for the logs and for tests. Individual sections keep
  /// whatever they had, so the page degrades instead of going blank.
  final List<String> degradedSections;

  /// What the customer is told about [degradedSections]. The section keys never
  /// reach the screen: they are English log labels, not a message.
  String? get error => degradedSections.isEmpty ? null : S.homeDegradedNotice;

  /// True when there is nothing to render - before the first row of anything
  /// has arrived, and after a load that failed on every section.
  bool get hasNoContent =>
      banners.isEmpty &&
      bundles.isEmpty &&
      categories.isEmpty &&
      popular.isEmpty &&
      recommendationPool.isEmpty;

  /// True before anything has ever loaded, which is different from loaded and
  /// found nothing.
  bool get isFirstLoad => isLoading && hasNoContent;

  /// The banner for the single promo slot below the categories: the second
  /// published one, so the slot does not repeat the slide the carousel opens on.
  BannerModel? get promoBanner {
    if (banners.length < 2) return null;
    return banners[1];
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
    List<String>? degradedSections,
  }) => HomeState(
    banners: banners ?? this.banners,
    bundles: bundles ?? this.bundles,
    categories: categories ?? this.categories,
    popular: popular ?? this.popular,
    recommendationPool: recommendationPool ?? this.recommendationPool,
    bundleProducts: bundleProducts ?? this.bundleProducts,
    isLoading: isLoading ?? this.isLoading,
    degradedSections: degradedSections ?? this.degradedSections,
  );
}
