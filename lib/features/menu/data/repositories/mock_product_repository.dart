import 'package:new_coffee/features/bundles/data/bundles_list.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/banners_list.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

/// Reads the catalogue from the Dart constants that predate the database.
///
/// Kept so the app still runs with no Supabase credentials, and so the two
/// implementations can be compared side by side. Delete this together with
/// menu_list.dart and categories_list.dart once the database path is the only
/// one in use.
class MockProductRepository implements CatalogRepository {
  const MockProductRepository();

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    var items = getMenuList();
    if (categoryId != null) {
      items = items
          .where((p) =>
              p.id == categoryId ||
              p.category.toLowerCase() == categoryId.toLowerCase())
          .toList();
    }
    if (offset >= items.length) return [];
    final end = (offset + limit).clamp(0, items.length);
    return items.sublist(offset, end);
  }

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    for (final p in getMenuList()) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<ProductWithOptions?> getWithOptions(String id, {String? branchId}) async {
    final product = await getById(id, branchId: branchId);
    if (product == null) return null;
    return ProductWithOptions(product: product);
  }

  @override
  Future<List<ProductModel>> search(
    String query, {
    String? branchId,
    String? categoryId,
    String sort = 'relevance',
    int limit = 20,
    int offset = 0,
  }) async {
    final q = query.trim().toLowerCase();
    var items = getMenuList();
    if (categoryId != null) {
      items = items.where((p) => p.category == categoryId).toList();
    }
    if (q.isNotEmpty) {
      items = items.where((p) => p.matches(q)).toList();
    }
    switch (sort) {
      case 'priceLowHigh':
        items.sort((a, b) => a.price.compareTo(b.price));
      case 'priceHighLow':
        items.sort((a, b) => b.price.compareTo(a.price));
      case 'nameAsc':
        items.sort((a, b) => a.name.compareTo(b.name));
    }
    if (offset >= items.length) return [];
    final end = (offset + limit).clamp(0, items.length);
    return items.sublist(offset, end);
  }

/// Products the database marks `is_featured`.
///
/// Mirrors the seed so the mock and the live repository agree on which
/// products are "featured". The old mock had no such concept, which is why
/// every product used to be shown as popular.
static const Set<String> _featuredNames = {
  'Espresso',
  'Cappuccino',
  'Latte',
  'Iced Latte',
  'Green Tea',
  'Cheesecake',
};

@override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = 10,
  }) async {
    final all = getMenuList();
    final featured = <FeaturedProduct>[
      for (final p in all)
        if (_featuredNames.contains(p.name))
          FeaturedProduct(
            productId: p.id,
            nameAr: '',
            nameEn: p.name,
            imageUrl: p.image,
            effectivePrice: p.price,
            source: 'manual',
          ),
    ];
    return featured.take(limit).toList();
  }

  /// No completed orders exist against the Dart constants, so this is always
  /// empty. That is the correct answer, not a stub.
  @override
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = 10,
  }) async =>
      const [];

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    String? branchId,
    List<String> optionValueIds = const [],
  }) async {
    final product = await getById(productId, branchId: branchId);
    if (product == null) return null;
    return ResolvedPrice(
      unitPrice: product.price,
      currencyCode: 'SAR',
      isAvailable: true,
    );
  }

  @override
  Future<List<BannerModel>> getBanners({int limit = 20}) async =>
      getBannersList().take(limit).toList();

  @override
  Future<List<BundleModel>> getBundles({String? branchId, int limit = 20}) async =>
      getBundlesList().take(limit).toList();

/// Legacy categories for the offline fallback.
///
/// These used to live in `features/categories/data/categories_list.dart`, a file
/// shared with the UI. Now that the UI reads from the repository, this mock is
/// the only consumer, so the data belongs here rather than in a shared module
/// that the app no longer uses.
///
/// [slug] is derived from the label so `getCategoryById` can keep resolving
/// keys the same way the old list did implicitly.
static final List<CategoryModel> _legacyCategories = [
  for (final label in const [
    'Hot Coffee',
    'Cold Coffee',
    'Tea',
    'Desserts',
    'Snacks',
    'Milkshakes',
    'Soft Drinks',
    'Bakery',
    'Donuts',
    'Bundles',
  ])
    CategoryModel(
      label: label,
      slug: label.toLowerCase().replaceAll(' ', '-'),
      icon: resolveCategoryIcon(label.toLowerCase().replaceAll(' ', '_')),
    ),
];

@override
  Future<List<CategoryModel>> getCategories({bool includeInactive = false}) async =>
      _legacyCategories;

  @override
  Future<CategoryModel?> getCategoryById(String id) async {
    for (final c in _legacyCategories) {
      if (c.slug == id) return c;
    }
    return null;
  }

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) => getCategoryById(slug);

  @override
  Future<List<CategoryModel>> getCategoryChildren(String parentId) async => const [];
}
