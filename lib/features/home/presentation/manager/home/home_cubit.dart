import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/di/branch_cubit_binding.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/bundles/data/bundle_pricing.dart'
    as pricing;
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/batch_product_repository.dart';
import 'package:new_coffee/features/weather/data/model/weather_model.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';

part 'home_state.dart';

/// Loads everything the home screen renders.
///
/// Before this, each of the seven home widgets called a Dart getter directly
/// during build, so the data was fixed at compile time and could not change
/// without a release. One cubit loads it once and every widget reads the same
/// snapshot, which is also one round trip instead of seven.
///
/// Sections that rarely move (banners, categories, bundles, featured rows) are
/// kept in [CacheManager] for its TTL, so reopening the page costs no queries.
/// A pull-to-refresh is the exception: it passes [load.forceRefresh] and goes
/// to the database, because a refresh gesture that hands back the cache it just
/// read is a gesture that does nothing.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required this._repository,
    this.branchId,
    BranchCubit? branchCubit,
  }) : super(const HomeState()) {
    if (branchCubit != null) _branchBinding.bind(branchCubit, setBranch);
    load();
  }

  final CatalogRepository _repository;
  final BranchCubitBinding _branchBinding = BranchCubitBinding();

  /// Branch whose prices and availability apply. Null until the customer picks.
  ///
  /// Mutable so [setBranch] can switch it. It was final before, which meant
  /// setBranch reloaded with the old value and silently did nothing.
  String? branchId;
  int _loadGeneration = 0;

  /// Candidate rows behind the recommendations strip.
  ///
  /// The strip itself shows [HomeState.maxRecommendations]; the pool is wider so
  /// the weather rule and the favourites have something to promote, and narrow
  /// enough that home never pulls the whole menu.
  static const int recommendationPoolSize = 10;

  Future<void> load({bool forceRefresh = false}) async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(isLoading: true, degradedSections: const []));

    // Each section loads independently so one failing source does not blank the
    // whole page. A section that fails keeps its previous value and the page
    // reports which ones are degraded.
    final failures = <String>[];

    Future<T> guard<T>(
      String section,
      Future<T> Function() run,
      T fallback,
    ) async {
      try {
        return await run();
      } catch (error, stackTrace) {
        failures.add(section);
        addError(error, stackTrace);
        return fallback;
      }
    }

    /// One section of the page: cache, then repository, then what was already
    /// on screen. Branch-dependent sections carry the branch in their key so two
    /// branches never share a snapshot.
    Future<T> section<T>(
      String name,
      String key,
      Future<T> Function() fetch,
      T fallback,
    ) => guard(name, () async {
      if (!forceRefresh) {
        final cached = CacheManager().get<T>(key);
        if (cached != null) return cached;
      }
      final fetched = await fetch();
      CacheManager().set(key, fetched);
      return fetched;
    }, fallback);

    final cacheBranch = branchId ?? 'base';

    final featuredFuture = section(
      'featured',
      'home_featured_$cacheBranch',
      () => _repository.getFeatured(
        branchId: branchId,
        limit: CatalogLimits.featured,
      ),
      const <FeaturedProduct>[],
    );
    // Also the candidate pool recommendations are ranked from, and the first
    // place bundle components are looked up in, so one query serves three
    // sections instead of three.
    final productsFuture = section(
      'products',
      'home_products_$cacheBranch',
      () => _repository.getProducts(
        branchId: branchId,
        limit: recommendationPoolSize,
      ),
      state.recommendationPool,
    );
    // Banners and categories belong to no branch, so their key stays unscoped.
    final bannersFuture = section(
      'banners',
      'home_banners',
      _repository.getBanners,
      state.banners,
    );
    final categoriesFuture = section(
      'categories',
      'home_categories',
      _repository.getCategories,
      state.categories,
    );
    final bundlesFuture = section(
      'bundles',
      'home_bundles_$cacheBranch',
      () => _repository.getBundles(branchId: branchId),
      state.bundles,
    );

    // Start every section before waiting. Sequential awaits on cache misses
    // turned independent requests into a network waterfall.
    final featured = await featuredFuture;
    final products = await productsFuture;
    final banners = await bannersFuture;
    final categories = await categoriesFuture;
    if (isClosed || generation != _loadGeneration) return;

    // Render the sections that are ready while the bundle list and its member
    // products finish loading. A slow bundle request should not hold the whole
    // home page behind a full-screen skeleton.
    emit(
      state.copyWith(
        banners: banners,
        categories: categories,
        popular: _toProducts(featured),
        recommendationPool: products,
        // A copy: the list is still being filled by the bundle reads below, and
        // a state must not change after it was emitted.
        degradedSections: List.of(failures),
      ),
    );

    final bundles = await bundlesFuture;
    if (isClosed || generation != _loadGeneration) return;

    // Resolve the products a bundle contains in one query, rather than per
    // card. This also replaces the old bundleProducts() helper, which read
    // them out of the Dart menu list.
    final componentIds = <String>{
      for (final b in bundles)
        for (final c in b.components) c.productId,
    }.toList();

    final productsById = <String, ProductModel>{
      for (final p in products) p.id: p,
    };

    // Resolve every bundle component, fetching any that the recommendation
    // pool did not already include so the before/after prices stay accurate
    // instead of silently dropping bundles with a discount.
    final missingComponentIds = componentIds
        .where((id) => !productsById.containsKey(id))
        .toList(growable: false);
    if (missingComponentIds.isNotEmpty) {
      try {
        final missingProducts = await getProductsByIds(
          _repository,
          missingComponentIds,
          branchId: branchId,
        );
        productsById.addAll({
          for (final product in missingProducts) product.id: product,
        });
      } catch (error, stackTrace) {
        failures.add('bundle_products');
        addError(error, stackTrace);
      }
    }
    final bundleProducts = <String, ProductModel>{};
    for (final id in componentIds) {
      final product = productsById[id];
      if (product != null) bundleProducts[id] = product;
    }

    if (isClosed || generation != _loadGeneration) return;
    emit(
      state.copyWith(
        banners: banners,
        bundles: bundles,
        categories: categories,
        popular: _toProducts(featured),
        recommendationPool: products,
        bundleProducts: bundleProducts,
        isLoading: false,
        degradedSections: List.of(failures),
      ),
    );
  }

  /// Products contained by the loaded bundles.
  ///
  /// The arithmetic lives with the bundles feature so home, the Bundles tab
  /// and the details page all report the same numbers for the same bundle.
  List<ProductModel> productsIn(BundleModel bundle) =>
      pricing.bundleProducts(bundle, state.bundleProducts);

  /// What the bundle contents would cost at their own prices.
  double originalTotalFor(BundleModel bundle) =>
      pricing.bundleOriginalTotal(bundle, state.bundleProducts);

  /// Reloads after the customer picks a different branch.
  ///
  /// Skips the reload when the branch is unchanged, so tapping the active
  /// branch chip does not refire five queries.
  ///
  /// The sections already on screen stay there while the new branch loads,
  /// which is what the catalogue cubits beside this one do. Clearing them first
  /// sent the page back behind a full skeleton on every branch switch.
  Future<void> setBranch(String? branchId) {
    if (branchId == this.branchId) return Future.value();
    this.branchId = branchId;
    return load();
  }

  /// The banner with the row its target points at, ready to be opened.
  ///
  /// A banner row carries the *id* of the product or bundle it is about, while
  /// the page behind that id takes the row itself, so the row is read here for
  /// the banners pressed on home. Category and url banners carry everything
  /// their target needs and cost no query.
  ///
  /// A row that cannot be read - unpublished between the list and the tap, or
  /// the network down - leaves the banner exactly as it came in, and the caller
  /// opens the banner page instead of an empty one.
  Future<BannerModel> resolveTarget(BannerModel banner) async {
    final id = banner.targetId;
    if (id == null) return banner;
    try {
      if (banner.target == BannerTarget.product &&
          banner.targetProduct == null) {
        return banner.copyWith(
          targetProduct: await _repository.getById(id, branchId: branchId),
        );
      }
      if (banner.target == BannerTarget.bundle && banner.targetBundle == null) {
        return banner.copyWith(
          targetBundle: await _repository.getBundleById(id),
        );
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    return banner;
  }

  @override
  Future<void> close() async {
    await _branchBinding.close();
    await super.close();
  }

  /// Featured rows carry the fields a card needs, so no second query is needed
  /// to render the carousel.
  ///
  /// The category name is included because [ProductCard] shows it in the
  /// subtitle slot; passing an empty string here left every "Popular" card with
  /// a blank subtitle even though the products are all categorised.
  static List<ProductModel> _toProducts(List<FeaturedProduct> featured) =>
      featured
          .map(
            (f) => ProductModel(
              id: f.productId,
              name: f.nameEn,
              nameAr: f.nameAr,
              nameEn: f.nameEn,
              categoryAr: f.categoryAr,
              categoryEn: f.categoryEn,
              description: '',
              price: f.effectivePrice,
              // The discount the server applied: it is what tells the card
              // there is a real promotion, so it can show the pre-discount
              // price beside the price.
              oldPrice: f.hasDiscount ? f.regularPrice : null,
              appliedDiscountPercentage: f.hasDiscount
                  ? f.discountPercentage
                  : null,
              image: f.imageUrl ?? '',
              isFeatured: f.source == 'manual',
            ),
          )
          .toList();
}
