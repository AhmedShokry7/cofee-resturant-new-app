import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'support/mock_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';

/// Cover for the home "Popular" row losing its category label.
///
/// HomeCubit turns each `get_featured` row into a ProductModel so the shared
/// ProductCard can render it, and that card shows the category in its subtitle
/// slot. The model used to be built with `category: ''`, so every featured card
/// showed a blank line — even though the products are all categorised and
/// `public.products` already carried the names. `get_featured` simply did not
/// return them, so the info never reached the card.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => CacheManager().clear());
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  Future<List<ProductModel>> popularFrom(
    List<FeaturedProduct> featured,
  ) async {
    final cubit = HomeCubit(
      repository: _FeaturedCatalog(featured),
    );
    final state = await cubit.stream.firstWhere((s) => !s.isLoading);
    await cubit.close();
    return state.popular;
  }

  test('a featured card shows its category name', () async {
    final popular = await popularFrom([
      const FeaturedProduct(
        productId: 'p1',
        nameAr: 'لاتيه',
        nameEn: 'Latte',
        effectivePrice: 12,
        source: 'manual',
        categoryAr: 'مشروبات ساخنة',
        categoryEn: 'Hot drinks',
      ),
    ]);

    AppLocale.instance.debugSet(AppLanguage.english);
    expect(popular.single.category, 'Hot drinks');
    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(popular.single.category, 'مشروبات ساخنة');
  });

  test('every featured row keeps its own category', () async {
    final popular = await popularFrom([
      const FeaturedProduct(
        productId: 'p1',
        nameAr: 'لاتيه',
        nameEn: 'Latte',
        effectivePrice: 12,
        source: 'manual',
        categoryAr: 'مشروبات ساخنة',
        categoryEn: 'Hot drinks',
      ),
      const FeaturedProduct(
        productId: 'p2',
        nameAr: 'موكا',
        nameEn: 'Mocha',
        effectivePrice: 14,
        source: 'manual',
        categoryAr: 'مشروبات باردة',
        categoryEn: 'Cold drinks',
      ),
    ]);

    AppLocale.instance.debugSet(AppLanguage.english);
    expect(popular.map((p) => p.category), ['Hot drinks', 'Cold drinks']);
  });

  test('an uncategorised product still appears, just without a label', () async {
    // The RPC uses a left join on purpose: an inner join would hide featured
    // products instead of showing them unlabelled.
    final popular = await popularFrom([
      const FeaturedProduct(
        productId: 'p1',
        nameAr: 'منتج',
        nameEn: 'Mystery',
        effectivePrice: 9,
        source: 'manual',
      ),
    ]);

    expect(popular, hasLength(1));
    expect(popular.single.nameEn, 'Mystery');
    expect(popular.single.category.trim(), isEmpty);
  });

  test('a row missing its Arabic name still shows the English one', () async {
    final popular = await popularFrom([
      const FeaturedProduct(
        productId: 'p1',
        nameAr: 'لاتيه',
        nameEn: 'Latte',
        effectivePrice: 12,
        source: 'manual',
        categoryEn: 'Hot drinks',
      ),
    ]);

    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(popular.single.category, 'Hot drinks');
  });
}

/// Catalogue that answers `get_featured` from a fixed list and delegates
/// everything else to the mock.
class _FeaturedCatalog implements CatalogRepository {
  _FeaturedCatalog(this.featured);

  final List<FeaturedProduct> featured;

  CatalogRepository get _inner => MockProductRepository();

  @override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = 10,
  }) async => featured.take(limit).toList();

  @override
  Future<List<BannerModel>> getBanners({int limit = 20}) async => const [];

  @override
  Future<List<BundleModel>> getBundles({String? branchId, int limit = 20}) =>
      _inner.getBundles(branchId: branchId, limit: limit);

  @override
  Future<BundleModel?> getBundleById(String id) => _inner.getBundleById(id);

  @override
  Future<List<CategoryModel>> getCategories({bool includeInactive = false}) =>
      _inner.getCategories(includeInactive: includeInactive);

  @override
  Future<CategoryModel?> getCategoryById(String id) => _inner.getCategoryById(id);

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
  Future<ProductWithOptions?> getWithOptions(
    String id, {
    String? branchId,
  }) => _inner.getWithOptions(id, branchId: branchId);

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
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = 10,
  }) => _inner.getBestSellers(
    branchId: branchId,
    period: period,
    limit: limit,
  );

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