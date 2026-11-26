import 'dart:async';

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
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';
import 'package:new_coffee/features/customer_bundles/data/repositories/customer_bundle_repository.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_event_request.dart';
import 'package:new_coffee/features/customer_reservations/data/repositories/customer_reservation_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/repositories/supabase_order_repository.dart';
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
  late final CustomerBundleRepository _customerBundleRepository =
      CustomerBundleRepository();
  late final CustomerReservationRepository _customerReservationRepository =
      CustomerReservationRepository();
  late final SupabaseProductRepository _customerBundleProductRepository =
      SupabaseProductRepository();
  final BranchCubitBinding _branchBinding = BranchCubitBinding();

  /// Branch whose prices and availability apply. Null until the customer picks.
  ///
  /// Mutable so [setBranch] can switch it. It was final before, which meant
  /// setBranch reloaded with the old value and silently did nothing.
  String? branchId;
  int _loadGeneration = 0;
  int _personalBundleGeneration = 0;
  Future<void>? _personalBundleInFlight;
  String? _loadedPersonalBundleUserId;
  String? _loadedPersonalBundleBranchId;
  String? _loadingPersonalBundleUserId;
  String? _loadingPersonalBundleBranchId;

  /// Candidate rows behind the recommendations strip.
  ///
  /// The strip itself shows [HomeState.maxRecommendations]; the pool is wider so
  /// the weather rule and the favourites have something to promote, and narrow
  /// enough that home never pulls the whole menu.
  static const int recommendationPoolSize = 30;

  Future<void> load({bool forceRefresh = false}) async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(isLoading: true, degradedSections: const []));
    // Customer bundles start with the rest of home, instead of waiting for the
    // personalized section to appear below the initial loading screen.
    // Keep this section in the same load cycle, but don't make the entire home
    // page wait for its independent bundle and product queries to finish.
    unawaited(loadPersonalBundles(forceRefresh: forceRefresh));
    final remindersFuture = SupabaseService.isSignedIn
        ? _customerReservationRepository.listMyUpcomingEventReminders()
        : Future.value(const <CustomerEventRequest>[]);

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
      'home_banners_v2',
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
    final userId = SupabaseService.isReady && SupabaseService.isSignedIn
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    final purchaseSignalsFuture = section<Map<String, int>>(
      'purchase_signals',
      'home_purchase_signals_${userId ?? 'guest'}_$cacheBranch',
      () async {
        if (userId == null) return const <String, int>{};
        final purchases = await SupabaseOrdersRepository().listOrders(
          status: OrderStatus.completed,
          limit: 100,
        );
        final purchasedIds = purchases
            .map((line) => line.product.id)
            .where((id) => id.isNotEmpty && !id.startsWith('removed-product-'))
            .toSet()
            .toList(growable: false);
        if (purchasedIds.isEmpty) return const <String, int>{};
        final purchaseFrequency = <String, int>{};
        for (final line in purchases) {
          purchaseFrequency.update(
            line.product.id,
            (count) => count + line.quantity,
            ifAbsent: () => line.quantity,
          );
        }
        final purchasedProducts = await getProductsByIds(
          _repository,
          purchasedIds,
          branchId: branchId,
        );
        final counts = <String, int>{};
        for (final product in purchasedProducts) {
          final category = product.categorySlug.trim();
          if (category.isNotEmpty) {
            final frequency = purchaseFrequency[product.id] ?? 1;
            counts.update(
              category,
              (count) => count + frequency,
              ifAbsent: () => frequency,
            );
          }
        }
        return counts;
      },
      state.purchaseCategoryCounts,
    );

    // Start every section before waiting. Sequential awaits on cache misses
    // turned independent requests into a network waterfall.
    final featured = await featuredFuture;
    final products = await productsFuture;
    final banners = await bannersFuture;
    final categories = await categoriesFuture;
    if (isClosed || generation != _loadGeneration) return;

    // Show the core catalog as soon as it is ready; personal bundles and
    // reminders continue loading alongside the page.
    emit(
      state.copyWith(
        banners: banners,
        categories: categories,
        popular: _toProducts(featured),
        recommendationPool: products,
        // Purchase history is only used to refine recommendations. Keep it out
        // of the critical path so a slow order-history query cannot hold home
        // content behind the loading state.
        purchaseCategoryCounts: state.purchaseCategoryCounts,
        hasLoadedOnce: true,
        isLoading:
            banners.isEmpty &&
            categories.isEmpty &&
            featured.isEmpty &&
            products.isEmpty &&
            state.personalBundles.isEmpty,
        // A copy: the list is still being filled by the bundle reads below, and
        // a state must not change after it was emitted.
        degradedSections: List.of(failures),
      ),
    );

    final reminders = await guard(
      'event_reminders',
      () => remindersFuture,
      state.eventReminders,
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

    // Resolve ranking signals after the page content is already visible. The
    // result is cached for the session TTL and updates recommendations once it
    // arrives.
    final purchaseCategoryCounts = await purchaseSignalsFuture;

    if (isClosed || generation != _loadGeneration) return;
    emit(
      state.copyWith(
        banners: banners,
        bundles: bundles,
        categories: categories,
        popular: _toProducts(featured),
        recommendationPool: products,
        purchaseCategoryCounts: purchaseCategoryCounts,
        bundleProducts: bundleProducts,
        eventReminders: reminders,
        isLoading: false,
        hasLoadedOnce: true,
        degradedSections: List.of(failures),
      ),
    );
  }

  /// Loads the signed-in customer's bundles and their branch-priced products.
  /// The home section calls this again after authentication or bundle edits.
  Future<void> loadPersonalBundles({bool forceRefresh = false}) {
    if (!SupabaseService.isReady || !SupabaseService.isSignedIn) {
      if (!forceRefresh &&
          !state.isPersonalBundlesLoading &&
          _loadedPersonalBundleUserId == null &&
          _loadedPersonalBundleBranchId == branchId) {
        return Future<void>.value();
      }
      ++_personalBundleGeneration;
      _personalBundleInFlight = null;
      _loadedPersonalBundleUserId = null;
      _loadedPersonalBundleBranchId = branchId;
      emit(
        state.copyWith(
          personalBundles: const [],
          personalBundleProducts: const {},
          isPersonalBundlesLoading: false,
          personalBundlesFailed: false,
        ),
      );
      return Future<void>.value();
    }
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return Future<void>.value();
    if (state.isPersonalBundlesLoading &&
        _loadingPersonalBundleUserId == userId &&
        _loadingPersonalBundleBranchId == branchId &&
        _personalBundleInFlight != null) {
      return _personalBundleInFlight!;
    }
    if (!forceRefresh &&
        _loadedPersonalBundleUserId == userId &&
        _loadedPersonalBundleBranchId == branchId) {
      return Future<void>.value();
    }
    final generation = ++_personalBundleGeneration;
    final bundleBranchId = branchId;
    _loadingPersonalBundleUserId = userId;
    _loadingPersonalBundleBranchId = bundleBranchId;
    emit(
      state.copyWith(
        isPersonalBundlesLoading: true,
        personalBundlesFailed: false,
      ),
    );
    final request = _fetchPersonalBundles(
      generation: generation,
      userId: userId,
      branchId: bundleBranchId,
    );
    _personalBundleInFlight = request;
    return request;
  }

  Future<void> _fetchPersonalBundles({
    required int generation,
    required String userId,
    required String? branchId,
  }) async {
    try {
      final bundles = (await _customerBundleRepository.listMyBundles())
          .where((bundle) => bundle.isActive)
          .toList(growable: false);
      final ids = bundles
          .expand((bundle) => bundle.items.map((item) => item.productId))
          .toSet()
          .toList(growable: false);
      final products = ids.isEmpty
          ? const <ProductModel>[]
          : await _customerBundleProductRepository.getByIds(
              ids,
              branchId: branchId,
            );
      if (isClosed || generation != _personalBundleGeneration) return;
      _loadedPersonalBundleUserId = userId;
      _loadedPersonalBundleBranchId = branchId;
      emit(
        state.copyWith(
          personalBundles: bundles,
          personalBundleProducts: {
            for (final product in products) product.id: product,
          },
          isPersonalBundlesLoading: false,
          personalBundlesFailed: false,
        ),
      );
    } catch (_) {
      if (isClosed || generation != _personalBundleGeneration) return;
      _loadedPersonalBundleUserId = null;
      _loadedPersonalBundleBranchId = null;
      emit(
        state.copyWith(
          personalBundles: const [],
          personalBundleProducts: const {},
          isPersonalBundlesLoading: false,
          personalBundlesFailed: true,
        ),
      );
    } finally {
      if (generation == _personalBundleGeneration) {
        _personalBundleInFlight = null;
      }
    }
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
