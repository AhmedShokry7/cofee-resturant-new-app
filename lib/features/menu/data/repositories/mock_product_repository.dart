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
      return ProductWithOptions(
        product: product,
        groups: _legacyOptionGroups(
          // Legacy mock products carry only a display label, so the slug has to
          // be derived or the lookup below misses and the screen shows nothing.
          product.categorySlug.isNotEmpty
              ? product.categorySlug
              : product.category.toLowerCase().replaceAll(' ', '-'),
        ),
      );
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
      _legacyBundles.take(limit).toList();

  /// Legacy bundles for the offline fallback.
  ///
  /// The details screen resolves components through the same mock catalogue,
  /// so these carry quantities rather than relying on the deleted shared
  /// helper to look products up globally.
  static final List<BundleModel> _legacyBundles = [
    _legacyBundle(
      id: 'morning-duo',
      title: 'Morning Duo',
      subtitle: 'Espresso + Butter Croissant',
      price: 48,
      productIds: ['1', '12'],
    ),
    _legacyBundle(
      id: 'sweet-break',
      title: 'Sweet Break',
      subtitle: 'Latte + Cheesecake',
      price: 79,
      productIds: ['3', '9'],
    ),
    _legacyBundle(
      id: 'iced-refresh',
      title: 'Iced Refresh',
      subtitle: 'Iced Latte + Glazed Donut',
      price: 56,
      productIds: ['6', '16'],
    ),
    _legacyBundle(
      id: 'tea-time',
      title: 'Tea Time',
      subtitle: 'Green Tea + Butter Bread',
      price: 42,
      productIds: ['7', '15'],
    ),
  ];

  static BundleModel _legacyBundle({
    required String id,
    required String title,
    required String subtitle,
    required double price,
    required List<String> productIds,
  }) {
    final components = [
      for (final productId in productIds)
        BundleComponent(productId: productId, quantity: 1),
    ];
    return BundleModel(
      id: id,
      title: title,
      subtitle: subtitle,
      productIds: productIds,
      price: price,
      components: components,
    );
  }

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

  /// Option groups for the offline path, mirroring the seed.
  ///
  /// The details screen reads these instead of frozen enums. Without them the
  /// offline build would silently lose the size, sugar and extras sections,
  /// which is worse than a slower screen.
  static List<OptionGroup> _legacyOptionGroups(String categorySlug) {
    OptionValue v(
      String id,
      String ar,
      String en,
      double delta,
      int order, {
      bool isDefault = false,
      String? short,
    }) =>
        OptionValue(
          id: id,
          code: id,
          nameAr: ar,
          nameEn: en,
          priceDelta: delta,
          isDefault: isDefault,
          sortOrder: order,
          shortLabel: short,
        );

    final size = OptionGroup(
      id: 'size',
      code: 'size',
      nameAr: 'الحجم',
      nameEn: 'Size',
      isSingleSelect: true,
      minSelect: 0,
      maxSelect: 1,
      isRequired: false,
      sortOrder: 1,
      values: [
        v('small', 'صغير', 'Small', 0, 1, isDefault: true, short: 'S'),
        v('medium', 'وسط', 'Medium', 5, 2, short: 'M'),
        v('large', 'كبير', 'Large', 10, 3, short: 'L'),
      ],
    );

    final sugar = OptionGroup(
      id: 'sugar',
      code: 'sugar',
      nameAr: 'السكر',
      nameEn: 'Sugar Level',
      isSingleSelect: true,
      minSelect: 0,
      maxSelect: 1,
      isRequired: false,
      sortOrder: 2,
      values: [
        v('none', 'بدون سكر', 'No Sugar', 0, 1, isDefault: true),
        v('less', 'سكر قليل', 'Less Sugar', 0, 2),
        v('normal', 'سكر عادي', 'Regular', 0, 3),
        v('extra', 'سكر كثير', 'Extra Sugar', 0, 4),
      ],
    );

    final extrasForCategory = <String, List<OptionValue>>{
      'hot-coffee': [
        v('shot', 'جرعة إسبريسو إضافية', 'Extra Espresso Shot', 8, 1),
        v('cream', 'كريمة مخفوقة', 'Whipped Cream', 5, 2),
        v('vanilla', 'شراب الفانيلا', 'Vanilla Syrup', 5, 3),
        v('caramel', 'شراب الكراميل', 'Caramel Syrup', 5, 4),
      ],
      'cold-coffee': [
        v('shot', 'جرعة إسبريسو إضافية', 'Extra Espresso Shot', 8, 1),
        v('cream', 'كريمة مخفوقة', 'Whipped Cream', 5, 2),
        v('vanilla', 'شراب الفانيلا', 'Vanilla Syrup', 5, 3),
        v('caramel', 'شراب الكراميل', 'Caramel Syrup', 5, 4),
      ],
      'tea': [
        v('mint', 'نعناع طازج', 'Fresh Mint', 3, 1),
        v('honey', 'عسل', 'Honey', 5, 2),
      ],
      'milkshakes': [
        v('cream', 'كريمة مخفوقة', 'Whipped Cream', 5, 1),
        v('scoop', 'كرة آيس كريم إضافية', 'Extra Ice Cream Scoop', 10, 2),
      ],
    };

    final extras = extrasForCategory[categorySlug];
    if (extras == null) return const [];

    return [
      size,
      sugar,
      OptionGroup(
        id: 'extras',
        code: 'extras',
        nameAr: 'الإضافات',
        nameEn: 'Extras',
        isSingleSelect: false,
        minSelect: 0,
        maxSelect: 6,
        isRequired: false,
        sortOrder: 3,
        values: extras,
      ),
    ];
  }

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) => getCategoryById(slug);

  @override
  Future<List<CategoryModel>> getCategoryChildren(String parentId) async => const [];
}
