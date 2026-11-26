part of 'home_cubit.dart';

@immutable
class HomeState {
  const HomeState({
    this.banners = const [],
    this.bundles = const [],
    this.categories = const [],
    this.popular = const [],
    this.recommendationPool = const [],
    this.purchaseCategoryCounts = const {},
    this.bundleProducts = const {},
    this.personalBundles = const [],
    this.personalBundleProducts = const {},
    this.eventReminders = const [],
    this.isPersonalBundlesLoading = true,
    this.personalBundlesFailed = false,
    this.hasLoadedOnce = false,
    this.isLoading = true,
    this.degradedSections = const [],
  });

  final List<BannerModel> banners;

  /// Banners assigned to the top carousel. Kept separate from the in-page slot
  /// so changing membership or order in one location cannot affect the other.
  List<BannerModel> get heroBanners => banners
      .where((banner) => banner.placement == BannerPlacement.hero)
      .toList(growable: false);

  /// Banners assigned to the independent in-page promotion slots.
  List<BannerModel> get inlineBanners => banners
      .where((banner) => banner.placement == BannerPlacement.inline)
      .toList(growable: false);

  final List<BundleModel> bundles;
  final List<CategoryModel> categories;

  /// Featured products: admin-pinned first, then best sellers.
  final List<ProductModel> popular;

  /// Candidate pool the recommendation rule filters. Loaded once so a weather
  /// change never triggers a query.
  final List<ProductModel> recommendationPool;

  /// Category affinity derived from the customer's completed order history.
  final Map<String, int> purchaseCategoryCounts;

  /// Products contained by the loaded bundles, keyed by product id.
  final Map<String, ProductModel> bundleProducts;

  /// Saved bundles belonging to the signed-in customer, priced for this branch.
  final List<CustomerBundle> personalBundles;
  final Map<String, ProductModel> personalBundleProducts;
  final List<CustomerEventRequest> eventReminders;
  final bool isPersonalBundlesLoading;
  final bool personalBundlesFailed;
  final bool hasLoadedOnce;

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
      recommendationPool.isEmpty &&
      personalBundles.isEmpty &&
      eventReminders.isEmpty;

  /// True before anything has ever loaded, which is different from loaded and
  /// found nothing.
  bool get isFirstLoad => isLoading && (!hasLoadedOnce || hasNoContent);

  /// البانر الترويجي عند فهرس من مستند التصميم، أو null لما لا وجود له.
  /// The index is relative to inline banners only.
  BannerModel? promoBannerAt(int index) {
    final candidates = inlineBanners;
    if (index < 0 || index >= candidates.length) return null;
    return candidates[index];
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

  /// The [recommendationPool] ordered using favorites, completed purchase
  /// categories, and the current weather, with the original catalog order as
  /// a stable tie-breaker.
  ///
  /// The home widget used to rank this during build, so the rule could not be
  /// tested and was re-run on every frame.
  List<ProductModel> recommendations({
    WeatherModel? weather,
    Set<String> favoriteIds = const {},
    Map<String, int> purchaseCategoryCounts = const {},
  }) {
    final seasonalSlugs = weather == null
        ? const <String>{}
        : weather.isHot
        ? hotDayCategorySlugs
        : coldDayCategorySlugs;
    int score(ProductModel product) =>
        (favoriteIds.contains(product.id) ? 2 : 0) +
        (purchaseCategoryCounts[product.categorySlug] ?? 0) * 2 +
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
    Map<String, int>? purchaseCategoryCounts,
    Map<String, ProductModel>? bundleProducts,
    List<CustomerBundle>? personalBundles,
    Map<String, ProductModel>? personalBundleProducts,
    List<CustomerEventRequest>? eventReminders,
    bool? isPersonalBundlesLoading,
    bool? personalBundlesFailed,
    bool? hasLoadedOnce,
    bool? isLoading,
    List<String>? degradedSections,
  }) => HomeState(
    banners: banners ?? this.banners,
    bundles: bundles ?? this.bundles,
    categories: categories ?? this.categories,
    popular: popular ?? this.popular,
    recommendationPool: recommendationPool ?? this.recommendationPool,
    purchaseCategoryCounts:
        purchaseCategoryCounts ?? this.purchaseCategoryCounts,
    bundleProducts: bundleProducts ?? this.bundleProducts,
    personalBundles: personalBundles ?? this.personalBundles,
    personalBundleProducts:
        personalBundleProducts ?? this.personalBundleProducts,
    eventReminders: eventReminders ?? this.eventReminders,
    isPersonalBundlesLoading:
        isPersonalBundlesLoading ?? this.isPersonalBundlesLoading,
    personalBundlesFailed: personalBundlesFailed ?? this.personalBundlesFailed,
    hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    isLoading: isLoading ?? this.isLoading,
    degradedSections: degradedSections ?? this.degradedSections,
  );
}
