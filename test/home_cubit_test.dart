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
    expect(state.error, contains('banners'));
    await cubit.close();
  });
}

/// Same catalogue, but the banner query throws.
class _FailingBannersCatalog implements CatalogRepository {
  _FailingBannersCatalog([CatalogRepository? inner])
    : _inner = inner ?? MockProductRepository();

  final CatalogRepository _inner;

  @override
  Future<List<BannerModel>> getBanners({int limit = 20}) =>
      throw StateError('banner source down');

  @override
  Future<List<BundleModel>> getBundles({String? branchId, int limit = 20}) =>
      _inner.getBundles(branchId: branchId, limit: limit);

  @override
  Future<BundleModel?> getBundleById(String id) => _inner.getBundleById(id);

  @override
  Future<List<CategoryModel>> getCategories({bool includeInactive = false}) =>
      _inner.getCategories(includeInactive: includeInactive);

  @override
  Future<CategoryModel?> getCategoryById(String id) =>
      _inner.getCategoryById(id);

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) =>
      _inner.getCategoryBySlug(slug);

  @override
  Future<List<CategoryModel>> getCategoryChildren(String parentId) =>
      _inner.getCategoryChildren(parentId);

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) =>
      _inner.getById(id, branchId: branchId);

  @override
  Future<ProductWithOptions?> getWithOptions(String id, {String? branchId}) =>
      _inner.getWithOptions(id, branchId: branchId);

  @override
  Future<Map<String, List<OptionGroup>>> getOptionsByProduct(
    List<String> productIds,
  ) => _inner.getOptionsByProduct(productIds);

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) => _inner.getProducts(
    branchId: branchId,
    categoryId: categoryId,
    limit: limit,
    offset: offset,
  );

  @override
  Future<List<ProductModel>> search(
    String query, {
    String? branchId,
    String? categoryId,
    String sort = 'relevance',
    int limit = 20,
    int offset = 0,
  }) => _inner.search(
    query,
    branchId: branchId,
    categoryId: categoryId,
    sort: sort,
    limit: limit,
    offset: offset,
  );

  @override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = 10,
  }) => _inner.getFeatured(branchId: branchId, limit: limit);

  @override
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = 10,
  }) => _inner.getBestSellers(branchId: branchId, period: period, limit: limit);

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    String? branchId,
    List<String> optionValueIds = const [],
  }) => _inner.resolvePrice(
    productId,
    branchId: branchId,
    optionValueIds: optionValueIds,
  );
}
