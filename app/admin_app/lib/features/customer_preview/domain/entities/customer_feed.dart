import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';

/// ما يراه العميل فعلًا من بيانات تقرأها اللوحة.
///
/// القواعد هنا ليست ذوقًا في العرض: كل قاعدة منها منقولة من مكان محدّد في تطبيق
/// العميل أو من سياسات الصف، حتى لا تعرض المعاينة شيئًا لا يراه الزبون فعلًا.
/// ما لا مصدر ثقة له عندها لا يُعرض إطلاقًا، بدل أن يُختَرع.
///
/// البطاقات كلها تخرج من هنا كنوع واحد [PreviewProduct]: بعضها محسوب من نافذة
/// الخصم التي تقرأها اللوحة، وبعضه راجع بالسعر النهائي من القاعدة نفسها
/// (شريط «الأكثر طلبًا»). شاشة المحاكي لا تفرّق بينهما، والعميل كذلك.
class CustomerFeed {
  /// يبني الكيان من قراءات اللوحة الخام. اللحظة تُحسب مرة واحدة، لأن نافذة
  /// الخصم ونافذة النشر تُقيسان عليها معًا؛ قراءتا `now` منفصلتان كانتا
  /// تقارنان صفًّا بوقتٍ وصفًّا بوقتٍ قبله.
  factory CustomerFeed({
    required List<AdminBanner> banners,
    required List<AdminCategory> categories,
    required List<AdminProduct> products,
    List<PreviewProduct> featured = const <PreviewProduct>[],
    List<AdminBundle> bundles = const <AdminBundle>[],
    double? temperature,
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now().toUtc();
    final catalog = products
        .where(_isSellable)
        .map((p) => _previewOf(p, _slugOf(categories, p.categoryId), moment))
        .toList(growable: false);
    return CustomerFeed._(
      publishedBanners: _visibleBanners(banners, moment),
      visibleCategories: categories.where((c) => c.isActive).toList(),
      catalog: catalog,
      featured: List.unmodifiable(featured),
      visibleBundles: bundles
          .where((bundle) => bundle.isActive)
          .take(bundleLimit)
          .toList(growable: false),
      temperature: temperature,
    );
  }

  const CustomerFeed._({
    required this.publishedBanners,
    required this.visibleCategories,
    required this.catalog,
    required this.featured,
    required this.visibleBundles,
    required this.temperature,
  });

  /// سقف عدد البنرات الذي يجلبه تطبيق العميل في شاشة واحدة
  /// (`CatalogLimits.banners`).
  static const int bannerLimit = 20;

  /// سقف الباقات في شريطها: `is_active` و`sort_order` وعشرون صفًا هناك.
  static const int bundleLimit = 20;

  /// عدد الصفوف التي يبني منها تطبيق العميل شريط «الأكثر طلبًا» وقائمة
  /// الترشيحات معًا (`HomeCubit.recommendationPoolSize`).
  static const int recommendationPoolSize = 10;

  /// ما يعرضه شريط الترشيحات من صفوف بعد الترتيب
  /// (`HomeState.maxRecommendations`).
  static const int maxRecommendations = 4;

  /// ما يعرضه الشريط قبل أن يتولّاه رابطه (`HomeProductsCarousel.maxItems`).
  static const int stripCap = 10;

  /// تصنيفات اليوم الحار واليوم البارد، من `HomeState` هناك.
  ///
  /// تُقارن بالـ slug لا بالاسم: تغيير اسم تصنيف لا يسقط القاعدة، وهو الخطأ
  /// الذي وقع حين كانت تطابق نصوصًا إنجليزية.
  static const Set<String> hotDayCategorySlugs = {
    'cold-coffee',
    'soft-drinks',
    'milkshakes',
  };
  static const Set<String> coldDayCategorySlugs = {'hot-coffee', 'tea'};

  /// درجة الحرارة عند الفرع، أو null بلا قراءة طقس.
  final double? temperature;

  final List<AdminBanner> publishedBanners;
  final List<AdminCategory> visibleCategories;

  /// المنتجات الصالحة للبيع كما تصل إلى بطاقة العميل، بترتيب الصف.
  final List<PreviewProduct> catalog;

  /// شريط «الأكثر طلبًا» كما رتّبته القاعدة وسعّرها.
  final List<PreviewProduct> featured;

  /// الباقات المنشورة بترتيبها.
  final List<AdminBundle> visibleBundles;

  /// هل الطقس حار عند الزبون: `WeatherModel.isHot` هناك، والخمس والعشرون درجة
  /// هي الحد. بلا قراءة طقس لا موسم ولا مقطع موسمي.
  bool get hasWeather => temperature != null;

  bool get isHotDay => hasWeather && temperature! >= 25;

  /// البانر الفردي تحت التصنيفات: الثاني في القائمة المنشورة، حتى لا يعيد
  /// المقطع تكرار الشريحة التي يفتحها الكاروسيل، ويختفي حين لا ثانٍ.
  AdminBanner? get promoBanner {
    final banners = publishedBanners;
    if (banners.length < 2) return null;
    return banners[1];
  }

  /// البركة التي يُرتَّب منها شريط الترشيحات: أول صفوف القائمة بترتيب الصف.
  List<PreviewProduct> get recommendationPool =>
      catalog.take(recommendationPoolSize).toList(growable: false);

  /// الترشيحات كما يرتّبها تطبيق العميل: ما يحبه الزبون أولًا، ثم ما يقترحه
  /// الطقس، ثم ترتيب القائمة.
  ///
  /// مفضّلة الزبون لا تُقرأ في اللوحة: سياسات الصف تربط
  /// `engagement.customer_favorites` بصاحب الحساب وحده، والمحاكي لا يقف على
  /// حساب زبون بعينه. لذلك تبقى نقاطها صفرًا دائمًا وترتّب المعاينة بقاعدة
  /// الطقس وحدها — وهو اختلاف معروض في السكة الجانبية لا مستور.
  ///
  /// الترتيب مستقر كما هناك: التعادل على النقاط يترك الصفوف بترتيبها.
  List<PreviewProduct> recommendations() {
    final weatherSlugs = !hasWeather
        ? const <String>{}
        : isHotDay
        ? hotDayCategorySlugs
        : coldDayCategorySlugs;
    int score(PreviewProduct product) =>
        weatherSlugs.contains(product.categorySlug) ? 1 : 0;
    final ranked = recommendationPool.indexed.toList()
      ..sort((a, b) {
        final byScore = score(b.$2).compareTo(score(a.$2));
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });
    return ranked
        .take(maxRecommendations)
        .map((entry) => entry.$2)
        .toList(growable: false);
  }

  /// بحث العميل داخل ما يُباع فقط؛ اسم عربي أو إنجليزي، بلا حساسية للحالة.
  List<PreviewProduct> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return catalog;
    return catalog
        .where(
          (p) =>
              p.nameAr.toLowerCase().contains(needle) ||
              p.nameEn.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  /// منتج التصنيف نفسه، بترتيب الشريط الأصلي في القائمة.
  List<PreviewProduct> productsInCategory(String categoryId) =>
      catalog.where((p) => p.categoryId == categoryId).toList(growable: false);

  /// إجمالي محتويات الباقة بأسعارها، وهو ما يُشطب فوق سعرها حين يكون أعلى منه.
  ///
  /// العميل يحسبه بأسعار منتجاته الجالبة في نفس الشاشة، واللوحة تجلب مكوّنات
  /// باقتها مع سعرها الأساسي في صفّ واحد: يتطابق الحسابان ما لم يكن للمنتج خصم
  /// نافذ خارج الصفحة التي قرأتها المعاينة.
  double bundleOriginalTotal(AdminBundle bundle) =>
      bundle.components.fold<double>(
        0,
        (sum, component) => sum + component.basePrice * component.quantity,
      );

  /// تصنيف «الباقات»: شاشة التصنيفات تعرض له قائمة الباقات لا شبكة المنتجات،
  /// لأن الباقة ليست صفًا في جدول المنتجات.
  ///
  /// المفتاح slug أولًا، والاسم احتياطًا لصفوف قديمة بلا slug، وهو يُقارن بما
  /// يخزنه الصف لا بالتسمية المعروضة: المعروضة تتبع لغة الواجهة فتنكسر القاعدة
  /// بتبديل اللغة.
  static const String bundlesCategorySlug = 'bundles';
  static const Set<String> bundlesCategoryNames = {
    bundlesCategorySlug,
    'الباقات',
  };

  static bool isBundlesCategory(AdminCategory? category) {
    if (category == null) return false;
    if (category.slug == bundlesCategorySlug) return true;
    return {
      category.nameAr,
      category.nameEn,
    }.any((name) => bundlesCategoryNames.contains(name.trim().toLowerCase()));
  }

  /// السعر الذي يدفعه العميل الآن لهذا المنتج، والسعر المشطوب فوقه.
  ///
  /// الحالتان منقولا من تطبيق العميل: خصم نافذ يجعل السعر الأساسي هو المشطوب
  /// (`supabase_product_repository.dart` هناك يضع `oldPrice = regular`)، وبلا
  /// خصم يبقى `compare_at_price` مرجعًا مشطوبًا إن كان أعلى من السعر. نافذة
  /// الخصم هي نافذة القاعدة نفسها (`AdminProduct.isDiscountActiveAt`)، فلا
  /// تعرض المعاينة خصمًا انتهى.
  static SimulatedPrice _priceOf(AdminProduct product, DateTime now) {
    final discounted = product.priceAfterDiscountAt(now);
    if (discounted != null) {
      return SimulatedPrice(
        price: discounted,
        oldPrice: product.basePrice > discounted ? product.basePrice : null,
      );
    }
    final compare = product.compareAtPrice;
    return SimulatedPrice(
      price: product.basePrice,
      oldPrice: compare != null && compare > product.basePrice ? compare : null,
    );
  }

  static PreviewProduct _previewOf(
    AdminProduct product,
    String categorySlug,
    DateTime now,
  ) {
    final price = _priceOf(product, now);
    return PreviewProduct(
      id: product.id,
      categoryId: product.categoryId,
      nameAr: product.nameAr,
      nameEn: product.nameEn,
      categoryAr: product.categoryNameAr ?? '',
      categoryEn: product.categoryNameEn ?? '',
      categorySlug: categorySlug,
      descriptionAr: product.descriptionAr,
      descriptionEn: product.descriptionEn,
      imageUrl: product.imageUrl,
      price: price.price,
      oldPrice: price.oldPrice,
      imageFit: product.imageFit,
    );
  }

  static String _slugOf(List<AdminCategory> categories, String? categoryId) {
    if (categoryId == null) return '';
    for (final category in categories) {
      if (category.id == categoryId) return category.slug;
    }
    return '';
  }

  static bool _isSellable(AdminProduct product) =>
      product.isActive && !product.isDraft && product.categoryId != null;

  /// نافذة النشر تُطبَّق في Dart كما يفعل تطبيق العميل: بنر منشور، ولم يبدأ
  /// وقته بعد أو انتهى وقته، لا يظهر.
  static List<AdminBanner> _visibleBanners(
    List<AdminBanner> banners,
    DateTime now,
  ) {
    final visible = banners.where((banner) {
      if (!banner.isPublished) return false;
      final start = banner.startsAt?.toUtc();
      if (start != null && now.isBefore(start)) return false;
      final end = banner.endsAt?.toUtc();
      if (end != null && now.isAfter(end)) return false;
      return true;
    }).toList();
    visible.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return visible.length > bannerLimit
        ? visible.sublist(0, bannerLimit)
        : visible;
  }
}

/// سعر كما يُطبع على بطاقة العميل: رقم، وسعر مشطوب فوقه إن وُجد.
class SimulatedPrice {
  const SimulatedPrice({required this.price, this.oldPrice});

  final double price;
  final double? oldPrice;
}
