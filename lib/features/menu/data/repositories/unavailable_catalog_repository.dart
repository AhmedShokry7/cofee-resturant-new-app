import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

/// Catalogue used when the backend could not be reached at startup.
///
/// It returns nothing. The alternative — the old mock catalogue — served
/// compiled-in products with their compiled-in prices, which in a store build
/// would show the customer a menu that does not exist and let them build an
/// order for it. An empty catalogue renders the app's own "no results" state,
/// which is honest, and it keeps the app alive instead of crashing on a
/// failed initialisation.
class UnavailableCatalogRepository implements CatalogRepository {
  const UnavailableCatalogRepository();

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) async => const [];

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async => null;

  @override
  Future<ProductWithOptions?> getWithOptions(
    String id, {
    String? branchId,
  }) async => null;

  @override
  Future<Map<String, List<OptionGroup>>> getOptionsByProduct(
    List<String> productIds,
  ) async => {};

  @override
  Future<List<ProductModel>> search(
    String query, {
    String? branchId,
    String? categoryId,
    String sort = 'relevance',
    int limit = 20,
    int offset = 0,
  }) async => const [];

  @override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = 10,
  }) async => const [];

  @override
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = 10,
  }) async => const [];

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    String? branchId,
    List<String> optionValueIds = const [],
  }) async => null;

  @override
  Future<List<BannerModel>> getBanners({int limit = 20}) async => const [];

  @override
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = 20,
  }) async => const [];

  @override
  Future<BundleModel?> getBundleById(String id) async => null;

  @override
  Future<List<CategoryModel>> getCategories({
    bool includeInactive = false,
  }) async => const [];

  @override
  Future<CategoryModel?> getCategoryById(String id) async => null;

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) async => null;

  @override
  Future<List<CategoryModel>> getCategoryChildren(String parentId) async =>
      const [];
}
