import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

/// Reads the catalogue from the Dart constants that predate the database.
///
/// Kept so the app still runs with no Supabase credentials, and so the two
/// implementations can be compared side by side. Delete this together with
/// menu_list.dart and categories_list.dart once the database path is the only
/// one in use.
class MockProductRepository implements CatalogRepository {
  MockProductRepository();

  /// Offline catalogue rows. These used to be a globally shared menu module;
  /// they now live inside the only implementation that reads them.
  static List<ProductModel> _legacyMenu = [
    ProductModel(
      id: "1",
      name: "Espresso",
      category: "Hot Coffee",
      description: "A rich and bold single shot of pure espresso, made from freshly ground premium beans. Served hot with a thick golden crema on top for a smooth, intense coffee experience.",
      price: 25,
      image: AppImages.product,
    ),
    ProductModel(
      id: "2",
      name: "Cappuccino",
      category: "Hot Coffee",
      description: "A classic favorite made with a balanced shot of espresso, topped with steamed milk and a generous layer of velvety milk foam. Perfect for any time of the day.",
      price: 40,
      oldPrice: 50,
      image: AppImages.product,
    ),
    ProductModel(
      id: "3",
      name: "Latte",
      category: "Hot Coffee",
      description: "Smooth espresso blended with plenty of steamed milk for a creamy, mellow flavor. Finished with a light layer of foam and a touch of natural sweetness.",
      price: 35,
      image: AppImages.product,
    ),
    ProductModel(
      id: "4",
      name: "Mocha",
      category: "Hot Coffee",
      description: "A decadent combination of rich espresso, steamed milk and premium chocolate syrup, topped with whipped cream. The perfect treat for chocolate and coffee lovers alike.",
      price: 45,
      oldPrice: 55,
      image: AppImages.product,
    ),
    ProductModel(
      id: "5",
      name: "Americano",
      category: "Hot Coffee",
      description: "Espresso diluted with hot water to create a lighter, smoother cup that keeps all the rich aroma of the beans. A clean and refreshing choice for everyday coffee.",
      price: 30,
      image: AppImages.product,
    ),
    ProductModel(
      id: "6",
      name: "Iced Latte",
      category: "Cold Coffee",
      description: "Chilled espresso poured over ice and combined with cold fresh milk for a refreshing, creamy drink. The ideal cool-down on a warm and sunny day.",
      price: 42,
      oldPrice: 50,
      image: AppImages.product,
    ),
    ProductModel(
      id: "7",
      name: "Green Tea",
      category: "Tea",
      description: "A light and refreshing green tea brewed from premium leaves, rich in antioxidants and perfect for a calm moment any time of the day.",
      price: 20,
      image: AppImages.product,
    ),
    ProductModel(
      id: "8",
      name: "Masala Tea",
      category: "Tea",
      description: "A warm spiced tea blended with milk, cardamom, ginger and cinnamon for a comforting and aromatic cup.",
      price: 25,
      image: AppImages.product,
    ),
    ProductModel(
      id: "9",
      name: "Cheesecake",
      category: "Desserts",
      description: "A rich and creamy cheesecake with a buttery biscuit base, baked to perfection and served chilled.",
      price: 55,
      oldPrice: 65,
      image: AppImages.product,
    ),
    ProductModel(
      id: "10",
      name: "Chocolate Brownie",
      category: "Desserts",
      description: "A warm, fudgy chocolate brownie made with premium cocoa, served soft in the middle with a rich chocolate flavor.",
      price: 48,
      image: AppImages.product,
    ),
    ProductModel(
      id: "11",
      name: "Chocolate Chip Cookie",
      category: "Snacks",
      description: "A freshly baked cookie loaded with melting chocolate chips. Crisp on the edges and soft in the center.",
      price: 18,
      image: AppImages.product,
    ),
    ProductModel(
      id: "12",
      name: "Butter Croissant",
      category: "Snacks",
      description: "A golden, flaky and buttery croissant baked fresh every morning. The perfect snack with your coffee.",
      price: 30,
      image: AppImages.product,
    ),
    ProductModel(
      id: "13",
      name: "Chocolate Milkshake",
      category: "Milkshakes",
      description: "A thick and creamy chocolate milkshake blended with premium ice cream and topped with whipped cream.",
      price: 45,
      oldPrice: 55,
      image: AppImages.product,
    ),
    ProductModel(
      id: "14",
      name: "Cola",
      category: "Soft Drinks",
      description: "A chilled glass of refreshing cola served over ice. The perfect fizzy companion to any meal.",
      price: 15,
      image: AppImages.product,
    ),
    ProductModel(
      id: "15",
      name: "Butter Bread",
      category: "Bakery",
      description: "A freshly baked loaf of soft butter bread, perfect for breakfast or a light snack.",
      price: 28,
      image: AppImages.product,
    ),
    ProductModel(
      id: "16",
      name: "Glazed Donut",
      category: "Donuts",
      description: "A soft and fluffy donut coated with a sweet glossy glaze. A classic treat for any time of the day.",
      price: 22,
      image: AppImages.product,
    ),
  ];

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    var items = List<ProductModel>.of(_legacyMenu);
    if (categoryId != null) {
      items = items
          .where(
            (p) =>
                p.id == categoryId ||
                p.category.toLowerCase() == categoryId.toLowerCase(),
          )
          .toList();
    }
    if (offset >= items.length) return [];
    final end = (offset + limit).clamp(0, items.length);
    return items.sublist(offset, end);
  }

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    for (final p in _legacyMenu) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<ProductWithOptions?> getWithOptions(
    String id, {
    String? branchId,
  }) async {
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
    var items = List<ProductModel>.of(_legacyMenu);
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
    final all = _legacyMenu;
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
  }) async => const [];

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

  /// Banners always come from the database. The offline fallback carries no
  /// fake banners: a fabricated banner would link to fabricated targets.
  @override
  Future<List<BannerModel>> getBanners({int limit = 20}) async => const [];

  @override
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = 20,
  }) async => _legacyBundles.take(limit).toList();

  @override
  Future<BundleModel?> getBundleById(String id) async {
    for (final b in _legacyBundles) {
      if (b.id == id) return b;
    }
    return null;
  }

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
  Future<List<CategoryModel>> getCategories({
    bool includeInactive = false,
  }) async => _legacyCategories;

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
    }) => OptionValue(
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
        v('mint', 'نعناع طازج', 'Fresh Mint', 3, 5),
        v('honey', 'عسل', 'Honey', 5, 6),
        v('scoop', 'كرة آيس كريم إضافية', 'Extra Ice Cream Scoop', 10, 7),
      ],
      'cold-coffee': [
        v('shot', 'جرعة إسبريسو إضافية', 'Extra Espresso Shot', 8, 1),
        v('cream', 'كريمة مخفوقة', 'Whipped Cream', 5, 2),
        v('vanilla', 'شراب الفانيلا', 'Vanilla Syrup', 5, 3),
        v('caramel', 'شراب الكراميل', 'Caramel Syrup', 5, 4),
        v('mint', 'نعناع طازج', 'Fresh Mint', 3, 5),
        v('honey', 'عسل', 'Honey', 5, 6),
        v('scoop', 'كرة آيس كريم إضافية', 'Extra Ice Cream Scoop', 10, 7),
      ],
      'tea': [
        v('shot', 'جرعة إسبريسو إضافية', 'Extra Espresso Shot', 8, 1),
        v('cream', 'كريمة مخفوقة', 'Whipped Cream', 5, 2),
        v('vanilla', 'شراب الفانيلا', 'Vanilla Syrup', 5, 3),
        v('caramel', 'شراب الكراميل', 'Caramel Syrup', 5, 4),
        v('mint', 'نعناع طازج', 'Fresh Mint', 3, 5),
        v('honey', 'عسل', 'Honey', 5, 6),
        v('scoop', 'كرة آيس كريم إضافية', 'Extra Ice Cream Scoop', 10, 7),
      ],
      'milkshakes': [
        v('shot', 'جرعة إسبريسو إضافية', 'Extra Espresso Shot', 8, 1),
        v('cream', 'كريمة مخفوقة', 'Whipped Cream', 5, 2),
        v('vanilla', 'شراب الفانيلا', 'Vanilla Syrup', 5, 3),
        v('caramel', 'شراب الكراميل', 'Caramel Syrup', 5, 4),
        v('mint', 'نعناع طازج', 'Fresh Mint', 3, 5),
        v('honey', 'عسل', 'Honey', 5, 6),
        v('scoop', 'كرة آيس كريم إضافية', 'Extra Ice Cream Scoop', 10, 7),
      ],
    };

    final extras = extrasForCategory[categorySlug];
    if (categorySlug == 'soft-drinks') return [size, sugar];
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
  Future<CategoryModel?> getCategoryBySlug(String slug) =>
      getCategoryById(slug);

  @override
  Future<List<CategoryModel>> getCategoryChildren(String parentId) async =>
      const [];
}
