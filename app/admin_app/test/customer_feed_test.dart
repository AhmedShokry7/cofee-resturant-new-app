import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';

/// زمن ثابت لكل اختبار: نافذتا النشر والخصم تقارنان بالساعة، فاختبارهما بلا
/// زمن مثبّت ينجح اليوم ويفشل بعد أسبوع.
final _now = DateTime.utc(2026, 11, 3, 12);

AdminBanner _banner(
  String id, {
  int sortOrder = 0,
  bool isPublished = true,
  DateTime? startsAt,
  DateTime? endsAt,
}) {
  return AdminBanner(
    id: id,
    titleAr: 'بانر $id',
    titleEn: 'Banner $id',
    imageUrl: 'https://example.com/$id.png',
    targetType: 'none',
    sortOrder: sortOrder,
    startsAt: startsAt,
    endsAt: endsAt,
    isPublished: isPublished,
  );
}

AdminCategory _category(String id, {bool isActive = true, String slug = ''}) {
  return AdminCategory(
    id: id,
    nameAr: 'تصنيف $id',
    nameEn: 'Category $id',
    isActive: isActive,
    slug: slug,
  );
}

AdminProduct _product(
  String id, {
  String? categoryId = 'c1',
  String? nameAr,
  bool isActive = true,
  bool isDraft = false,
  bool isFeatured = false,
  double basePrice = 20,
  double? compareAtPrice,
  double? discountPercentage,
  DateTime? discountStartsAt,
  DateTime? discountEndsAt,
}) {
  return AdminProduct(
    id: id,
    nameAr: nameAr ?? 'قهوة $id',
    nameEn: 'Coffee $id',
    sku: 'sku-$id',
    slug: 'slug-$id',
    basePrice: basePrice,
    categoryId: categoryId,
    isActive: isActive,
    isDraft: isDraft,
    isFeatured: isFeatured,
    compareAtPrice: compareAtPrice,
    discountPercentage: discountPercentage,
    discountStartsAt: discountStartsAt,
    discountEndsAt: discountEndsAt,
  );
}

/// صفّ شريط «الأكثر طلبًا» كما يرجعه `get_featured`: الاسم والسعر محسوبان
/// عند القاعدة، فلا تحسبهما المعاينة ثانية.
const PreviewProduct _featuredRow = PreviewProduct(
  id: 'f1',
  nameAr: 'أكثر طلبًا',
  nameEn: 'Top seller',
  price: 33,
);

CustomerFeed _feed({
  List<AdminBanner> banners = const [],
  List<AdminCategory> categories = const [],
  List<AdminProduct> products = const [],
  List<PreviewProduct> featured = const [],
  List<AdminBundle> bundles = const [],
  double? temperature,
}) {
  return CustomerFeed(
    banners: banners,
    categories: categories,
    products: products,
    featured: featured,
    bundles: bundles,
    temperature: temperature,
    now: _now,
  );
}

void main() {
  group('البنرات التي يراها الزبون', () {
    test('تُطوى على المنشور داخل نافذته فقط', () {
      final feed = _feed(
        banners: [
          _banner(
            'later',
            sortOrder: 4,
            startsAt: _now.add(const Duration(hours: 1)),
          ),
          _banner('live', sortOrder: 1),
          _banner(
            'gone',
            sortOrder: 2,
            endsAt: _now.subtract(const Duration(hours: 1)),
          ),
          _banner('hidden', sortOrder: 3, isPublished: false),
          _banner('open-ended', sortOrder: 5, startsAt: _now),
        ],
      );

      expect(feed.publishedBanners.map((b) => b.id), ['live', 'open-ended']);
    });

    test('ترتيب العرض هو sortOrder ثم سقف العدد', () {
      final many = [
        for (var i = 0; i < 25; i++) _banner('$i', sortOrder: 25 - i),
      ];
      final feed = _feed(banners: many);

      expect(feed.publishedBanners.length, CustomerFeed.bannerLimit);
      expect(feed.publishedBanners.first.sortOrder, 1);
      expect(feed.publishedBanners.last.sortOrder, 20);
    });

    test('البانر الفردي هو الثاني، ويختفي حين لا ثانٍ', () {
      expect(_feed(banners: [_banner('a')]).promoBanner, isNull);

      final two = _feed(
        banners: [_banner('a', sortOrder: 1), _banner('b', sortOrder: 2)],
      );
      expect(two.promoBanner?.id, 'b');
    });
  });

  group('التصنيفات والمنتجات القابلة للبيع', () {
    test('التصنيف غير النشط لا يصل للشاشة', () {
      final feed = _feed(
        categories: [_category('c1'), _category('off', isActive: false)],
      );

      expect(feed.visibleCategories.map((c) => c.id), ['c1']);
    });

    test('المخفي والمسودة ومنتج بلا تصنيف لا تُباع للعميل', () {
      final feed = _feed(
        products: [
          _product('ok'),
          _product('inactive', isActive: false),
          _product('draft', isDraft: true),
          _product('homeless', categoryId: null),
        ],
      );

      expect(feed.catalog.map((p) => p.id), ['ok']);
    });

    test('شريط الأكثر طلبًا يصل كما رتّبته القاعدة وبأسعارها', () {
      final feed = _feed(
        products: [_product('in-catalog', basePrice: 20)],
        featured: const [
          _featuredRow,
          PreviewProduct(id: 'f2', nameAr: 'ثانٍ', nameEn: 'Second', price: 9),
        ],
      );

      // لا تُعيد المعاينة ترتيب الشريط ولا حساب سعره: الترتيب والسعر قرار الصف.
      expect(feed.featured.map((p) => p.id), ['f1', 'f2']);
      expect(feed.featured.first.price, 33);
      expect(feed.catalog.map((p) => p.id), ['in-catalog']);
    });
  });

  group('البحث والتصنيف', () {
    test('البحث يطابق العربية والإنجليزية بلا حساسية للحالة', () {
      final feed = _feed(
        products: [
          _product('latte', nameAr: 'لاتيه'),
          _product('mocha'),
        ],
      );

      expect(feed.search('لاتيه').map((p) => p.id), ['latte']);
      expect(feed.search('COFFEE mocha').map((p) => p.id), ['mocha']);
      expect(feed.search('   ').length, 2);
      expect(feed.search('شاي'), isEmpty);
    });

    test('منتجات التصنيف لا تعبر حدوده', () {
      final feed = _feed(
        products: [
          _product('a', categoryId: 'c1'),
          _product('b', categoryId: 'c2'),
        ],
      );

      expect(feed.productsInCategory('c1').map((p) => p.id), ['a']);
    });
  });

  group('سعر بطاقة العميل', () {
    test('خصم نافذ: السعر المخفّض هو المعروض والأساس فوقه مشطوب', () {
      final feed = _feed(
        products: [
          _product(
            'sale',
            basePrice: 100,
            discountPercentage: 25,
            discountStartsAt: _now.subtract(const Duration(days: 1)),
            discountEndsAt: _now.add(const Duration(days: 1)),
          ),
        ],
      );

      expect(feed.catalog.first.price, 75);
      expect(feed.catalog.first.oldPrice, 100);
    });

    test('خصم لم يبدأ أو انتهى لا يُطبع خصمًا', () {
      final feed = _feed(
        products: [
          _product(
            'not-yet',
            basePrice: 100,
            discountPercentage: 50,
            discountStartsAt: _now.add(const Duration(days: 1)),
          ),
          _product(
            'expired',
            basePrice: 100,
            discountPercentage: 50,
            discountEndsAt: _now.subtract(const Duration(minutes: 1)),
          ),
        ],
      );

      for (final product in feed.catalog) {
        expect(product.price, 100);
        expect(product.oldPrice, isNull);
      }
    });

    test('بلا خصم: السعر الأساسي هو المعروض، والمشطوب فقط حين يكون أعلى', () {
      final feed = _feed(
        products: [
          _product('higher', basePrice: 40, compareAtPrice: 55),
          _product('equal', basePrice: 40, compareAtPrice: 40),
          _product('lower', basePrice: 40, compareAtPrice: 30),
        ],
      );

      PreviewProduct row(String id) =>
          feed.catalog.firstWhere((p) => p.id == id);

      expect(row('higher').price, 40);
      expect(row('higher').oldPrice, 55);
      expect(row('equal').oldPrice, isNull);
      expect(row('lower').oldPrice, isNull);
    });
  });

  group('موسم الترشيحات', () {
    test('الحرارة عند الحد تصنع يومًا حارًا، وبلا قراءة لا موسم', () {
      expect(_feed(temperature: 25).isHotDay, isTrue);
      expect(_feed(temperature: 24.9).isHotDay, isFalse);
      expect(_feed().hasWeather, isFalse);
      expect(_feed().isHotDay, isFalse);
    });

    test('اليوم الحار يقدّم تصنيفات المشروبات الباردة', () {
      final feed = _feed(
        categories: [
          _category('cold', slug: 'cold-coffee'),
          _category('hot', slug: 'hot-coffee'),
        ],
        products: [
          _product('a', categoryId: 'hot'),
          _product('b', categoryId: 'cold'),
          _product('c', categoryId: 'hot'),
        ],
        temperature: 30,
      );

      expect(feed.recommendations().map((p) => p.id), ['b', 'a', 'c']);
    });

    test('اليوم البارد يقدّم الساخن، والتعادل يترك ترتيب القائمة', () {
      final feed = _feed(
        categories: [
          _category('cold', slug: 'cold-coffee'),
          _category('hot', slug: 'hot-coffee'),
        ],
        products: [
          _product('a', categoryId: 'cold'),
          _product('b', categoryId: 'hot'),
          _product('c', categoryId: 'cold'),
        ],
        temperature: 8,
      );

      expect(feed.recommendations().map((p) => p.id), ['b', 'a', 'c']);
    });

    test('بلا طقس تُعرض البركة بترتيبها، وسقفها ثم سقف الشريط', () {
      final feed = _feed(
        products: [for (var i = 0; i < 12; i++) _product('$i')],
      );

      expect(
        feed.recommendationPool.length,
        CustomerFeed.recommendationPoolSize,
      );
      expect(
        feed.recommendations().map((p) => p.id),
        List.generate(CustomerFeed.maxRecommendations, (i) => '$i'),
      );
    });

    test('منتج بلا slug تصنيفي لا يدخل موسمًا', () {
      final feed = _feed(
        categories: [_category('c1')],
        products: [_product('plain', categoryId: 'c1')],
        temperature: 30,
      );

      expect(feed.catalog.first.categorySlug, isEmpty);
      expect(feed.recommendations().map((p) => p.id), ['plain']);
    });
  });

  group('الباقات كما يراها الزبون', () {
    final bundle = AdminBundle(
      id: 'bd1',
      nameAr: 'باقة الصباح',
      nameEn: 'Morning bundle',
      bundlePrice: 45,
      components: const [
        AdminBundleComponent(productId: 'p1', quantity: 2, basePrice: 20),
        AdminBundleComponent(productId: 'p2', quantity: 1, basePrice: 15),
      ],
    );

    test('النشط منها فقط، بترتيبه وسقفه', () {
      final feed = _feed(
        bundles: [
          bundle,
          AdminBundle(
            id: 'bd2',
            nameAr: 'موقوفة',
            nameEn: 'Off',
            isActive: false,
          ),
          for (var i = 0; i < 25; i++)
            AdminBundle(id: 'x$i', nameAr: 'باقة $i', nameEn: 'Bundle $i'),
        ],
      );

      expect(feed.visibleBundles.length, CustomerFeed.bundleLimit);
      expect(feed.visibleBundles.first.id, 'bd1');
      expect(
        feed.visibleBundles.any((b) => b.id == 'bd2'),
        isFalse,
        reason: 'الباقة الموقوفة لا تصل شاشة الزبون',
      );
    });

    test('المشطوب فوق الباقة هو إجمالي محتوياتها بأسعارها وكمياتها', () {
      final feed = _feed(bundles: [bundle]);

      expect(feed.bundleOriginalTotal(bundle), 55);
    });

    test('خانة «الباقات» تُعرّف بالـ slug ثم بالاسم المخزّن', () {
      expect(
        CustomerFeed.isBundlesCategory(
          _category('any', slug: CustomerFeed.bundlesCategorySlug),
        ),
        isTrue,
      );
      expect(
        CustomerFeed.isBundlesCategory(
          const AdminCategory(id: 'old', nameAr: 'الباقات', nameEn: 'bundles'),
        ),
        isTrue,
      );
      expect(
        CustomerFeed.isBundlesCategory(
          const AdminCategory(id: 'near', nameAr: 'باقات', nameEn: 'Deals'),
        ),
        isFalse,
        reason: 'الاسم المعروض يتبع لغة الواجهة، فلا تُقارن القاعدة به',
      );
      expect(
        CustomerFeed.isBundlesCategory(null),
        isFalse,
        reason: 'بلا تصنيف لا قائمة باقات',
      );
    });
  });
}
