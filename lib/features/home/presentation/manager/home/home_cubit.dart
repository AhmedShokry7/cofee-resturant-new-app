import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
/// بيانات الصفحة الرئيسية تُخزّن مؤقتاً في ذاكرة الجهاز ([CacheManager]) لمدة
/// 5 دقائق لتجنب إعادة طلب نفس البيانات من Supabase في كل opening للصفحة،
/// مما يخفف الحمل على قاعدة البيانات عند ازدياد عدد المستخدمين المتزامنين.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required this._repository, this.branchId})
    : super(const HomeState()) {
    load();
  }

  final CatalogRepository _repository;

  /// Branch whose prices and availability apply. Null until the customer picks.
  ///
  /// Mutable so [setBranch] can switch it. It was final before, which meant
  /// setBranch reloaded with the old value and silently did nothing.
  String? branchId;
  int _loadGeneration = 0;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(isLoading: true, error: null));

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

    //cache key includes branchId so different branches don't share stale data.
    final cacheBranch = branchId ?? 'base';

    // البانرات تتغير rarement — تُجلب من الكاش إذا كانت متوفرة.
    final bannersFuture = guard('banners', () async {
      final key = 'home_banners';
      final cached = CacheManager().get<List<BannerModel>>(key);
      if (cached != null) return cached;
      final fetched = await _repository.getBanners();
      CacheManager().set(key, fetched);
      return fetched;
    }, state.banners);
    final bundlesFuture = guard('bundles', () async {
      final key = 'home_bundles_$cacheBranch';
      final cached = CacheManager().get<List<BundleModel>>(key);
      if (cached != null) return cached;
      final fetched = await _repository.getBundles(branchId: branchId);
      CacheManager().set(key, fetched);
      return fetched;
    }, state.bundles);
    final categoriesFuture = guard('categories', () async {
      final key = 'home_categories';
      final cached = CacheManager().get<List<CategoryModel>>(key);
      if (cached != null) return cached;
      final fetched = await _repository.getCategories();
      CacheManager().set(key, fetched);
      return fetched;
    }, state.categories);
    final featuredFuture = guard('featured', () async {
      final key = 'home_featured_$cacheBranch';
      final cached = CacheManager().get<List<FeaturedProduct>>(key);
      if (cached != null) return cached;
      final fetched = await _repository.getFeatured(
        branchId: branchId,
        limit: 10,
      );
      CacheManager().set(key, fetched);
      return fetched;
    }, const <FeaturedProduct>[]);
    // Candidate pool for recommendations. Loaded once here so the weather
    // rule can filter it without a query per temperature change.
    final productsFuture = guard('products', () async {
      final key = 'home_products_$cacheBranch';
      final cached = CacheManager().get<List<ProductModel>>(key);
      if (cached != null) return cached;
      final fetched = await _repository.getProducts(
        branchId: branchId,
        limit: 10,
      );
      CacheManager().set(key, fetched);
      return fetched;
    }, state.recommendationPool);

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
      HomeState(
        banners: banners,
        categories: categories,
        popular: _toProducts(featured),
        recommendationPool: products,
        bundles: state.bundles,
        bundleProducts: state.bundleProducts,
        isLoading: true,
        error: failures.isEmpty ? null : 'Degraded: ${failures.join(', ')}',
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
    // pool did not already include so prices (and the discount badge) stay
    // accurate instead of silently dropping bundles with a discount.
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
      HomeState(
        banners: banners,
        bundles: bundles,
        categories: categories,
        popular: _toProducts(featured),
        recommendationPool: products,
        bundleProducts: bundleProducts,
        isLoading: false,
        error: failures.isEmpty ? null : 'Degraded: ${failures.join(', ')}',
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

  /// Never negative: a bundle can be priced above its contents.
  double savingFor(BundleModel bundle) =>
      pricing.bundleSavings(bundle, state.bundleProducts);

  /// Whole percent the customer keeps, zero when the bundle saves nothing.
  int savingPercentFor(BundleModel bundle) =>
      pricing.bundleSavingPercent(bundle, state.bundleProducts);

  /// Reloads after the customer picks a different branch.
  ///
  /// Skips the reload when the branch is unchanged, so tapping the active
  /// branch chip does not refire five queries.
  Future<void> setBranch(String? branchId) {
    if (branchId == this.branchId) return Future.value();
    this.branchId = branchId;
    emit(const HomeState());
    return load();
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
              // The discount the server applied, so the badge on a "Popular"
              // card states the real percentage.
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
