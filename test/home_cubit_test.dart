import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

import 'support/mock_product_repository.dart';

import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';

/// Home page loading contract.
///
/// Banners come only from the database (the mock carries none), and one
/// failing section must degrade with a named error instead of blanking the
/// whole page.
void main() {
  setUp(() => CacheManager().clear());

  Future<HomeState> loadFinished(HomeCubit cubit) =>
      cubit.stream.firstWhere((s) => !s.isLoading);

  test('loads catalogue sections from the repository', () async {
    final cubit = HomeCubit(repository: MockProductRepository());
    final state = await loadFinished(cubit);

    expect(
      state.banners,
      isEmpty,
      reason: 'mock carries no banners; they are DB-only',
    );
    expect(state.recommendationPool, isNotEmpty);
    expect(state.categories, isNotEmpty);
    expect(state.bundles, isNotEmpty);
    expect(state.error, isNull);
    await cubit.close();
  });

  test('a failing banners source degrades instead of blanking home', () async {
    final cubit = HomeCubit(repository: _FailingBannersCatalog());
    final state = await loadFinished(cubit);

    expect(state.banners, isEmpty);
    expect(
      state.recommendationPool,
      isNotEmpty,
      reason: 'products must survive a banners failure',
    );
    expect(state.categories, isNotEmpty);
    expect(
      state.degradedSections,
      contains('banners'),
      reason: 'the machine name stays in the state; the screen localises it',
    );
    expect(state.error, isNot(contains('banners')));
    await cubit.close();
  });

  test(
    'pull-to-refresh reads past the cache, a plain reload does not',
    () async {
      final catalog = _CountingBannersCatalog();
      final cubit = HomeCubit(repository: catalog);
      await loadFinished(cubit);
      expect(catalog.bannerReads, 1, reason: 'the cold start fills the cache');

      await cubit.load();
      expect(
        catalog.bannerReads,
        1,
        reason: 'a reload inside the TTL is answered from the cache',
      );

      await cubit.load(forceRefresh: true);
      expect(
        catalog.bannerReads,
        2,
        reason: 'the refresh gesture must reach the database it just cached',
      );
      await cubit.close();
    },
  );

  test(
    'a product banner is given its product when a tap asks for it',
    () async {
      final cubit = HomeCubit(repository: _CountingBannersCatalog());
      await loadFinished(cubit);

      const banner = BannerModel(
        id: 'pb',
        image: '',
        target: BannerTarget.product,
        targetId: '2',
      );
      expect(
        banner.targetProduct,
        isNull,
        reason: 'the home row carries the id, not the product',
      );

      final resolved = await cubit.resolveTarget(banner);
      expect(resolved.targetProduct?.id, '2');

      // Once the banner carries the row, pressing it again reads nothing.
      expect(identical(await cubit.resolveTarget(resolved), resolved), isTrue);
      await cubit.close();
    },
  );

  test('a bundle banner is given its bundle', () async {
    final cubit = HomeCubit(repository: _CountingBannersCatalog());
    await loadFinished(cubit);

    const banner = BannerModel(
      id: 'bb',
      image: '',
      target: BannerTarget.bundle,
      targetId: 'morning-duo',
    );
    expect((await cubit.resolveTarget(banner)).targetBundle?.id, 'morning-duo');
    await cubit.close();
  });

  test(
    'a category banner reads nothing, and a row that is gone reads nothing',
    () async {
      final cubit = HomeCubit(repository: _CountingBannersCatalog());
      await loadFinished(cubit);

      const category = BannerModel(
        id: 'cb',
        image: '',
        target: BannerTarget.category,
        targetId: 'cat-1',
      );
      expect(
        identical(await cubit.resolveTarget(category), category),
        isTrue,
        reason: 'the category page takes the id the banner already carries',
      );

      const gone = BannerModel(
        id: 'gb',
        image: '',
        target: BannerTarget.product,
        targetId: 'no-such-product',
      );
      expect(
        (await cubit.resolveTarget(gone)).targetProduct,
        isNull,
        reason: 'a row unpublished between the list and the tap leaves the banner as it came',
      );
      await cubit.close();
    },
  );
}

/// The mock catalogue, counting how often the banner query ran.
class _CountingBannersCatalog extends _ForwardingCatalog {
  int bannerReads = 0;

  @override
  Future<List<BannerModel>> getBanners({int limit = CatalogLimits.banners}) {
    bannerReads++;
    return _inner.getBanners(limit: limit);
  }
}

/// The mock catalogue, listing only the reads a home load performs.
///
/// Anything else answers loudly, so a new section on home cannot start reading a
/// source this file had not accounted for.
class _ForwardingCatalog implements CatalogRepository {
  _ForwardingCatalog() : _inner = MockProductRepository();

  final CatalogRepository _inner;

  @override
  Future<List<BannerModel>> getBanners({int limit = CatalogLimits.banners}) =>
      _inner.getBanners(limit: limit);

  @override
  Future<List<CategoryModel>> getCategories({bool includeInactive = false}) =>
      _inner.getCategories(includeInactive: includeInactive);

  @override
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = CatalogLimits.bundles,
  }) => _inner.getBundles(branchId: branchId, limit: limit);

  @override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = CatalogLimits.featured,
  }) => _inner.getFeatured(branchId: branchId, limit: limit);

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) =>
      _inner.getById(id, branchId: branchId);

  @override
  Future<BundleModel?> getBundleById(String id) => _inner.getBundleById(id);

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = CatalogLimits.products,
    int offset = 0,
  }) => _inner.getProducts(
    branchId: branchId,
    categoryId: categoryId,
    limit: limit,
    offset: offset,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('home does not read ${invocation.memberName}');
}

/// Same catalogue, but the banner query throws.
class _FailingBannersCatalog extends _ForwardingCatalog {
  @override
  Future<List<BannerModel>> getBanners({int limit = CatalogLimits.banners}) =>
      throw StateError('banner source down');
}
