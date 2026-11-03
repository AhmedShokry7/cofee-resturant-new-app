import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';
import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/domain/entities/simulator_tab.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/customer_preview_repository.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/customer_preview_cubit.dart';
import 'package:admin_app/features/customer_preview/presentation/pages/customer_preview_page.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/customer_preview_rail.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/phone_frame.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_banner_carousel.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_bottom_bar.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_category_marquee.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_category_tabs.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_home_screen.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_grid.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_promo_banner.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_search_field.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_tokens.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_viewport.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

final _now = DateTime.utc(2026, 11, 3, 12);

/// قارئ كتالوج وهمي: يعيد صفًّا جاهزًا بلا شبكة، ويقرّر الاختبار أن يرفض أو
/// ينجح ليُرى مسارا الفشل وإعادة القراءة.
class _CatalogFake implements CatalogData {
  _CatalogFake({
    this.snapshot = const AdminCatalogSnapshot(products: [], categories: []),
    this.refuse = false,
  });

  AdminCatalogSnapshot snapshot;
  bool refuse;
  int loads = 0;

  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) {
    loads++;
    if (refuse) return Future<AdminCatalogSnapshot>.error(StateError('500'));
    return Future.value(snapshot);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

/// قارئ البنرات الوهمي لا يعرف إلا القائمة التي أعطيها.
class _BannersFake implements BannerRepository {
  _BannersFake({this.banners = const [], this.refuse = false});

  List<AdminBanner> banners;
  bool refuse;

  @override
  Future<List<AdminBanner>> loadBanners() {
    if (refuse) return Future<List<AdminBanner>>.error(StateError('500'));
    return Future.value(banners);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class _BundlesFake implements BundleRepository {
  _BundlesFake({this.bundles = const [], this.refuse = false});

  List<AdminBundle> bundles;
  bool refuse;

  @override
  Future<List<AdminBundle>> loadBundles() {
    if (refuse) return Future<List<AdminBundle>>.error(StateError('500'));
    return Future.value(bundles);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class _BranchesFake implements BranchRepository {
  _BranchesFake({this.branches = const [], this.refuse = false});

  List<AdminBranch> branches;
  bool refuse;

  @override
  Future<List<AdminBranch>> loadBranches() {
    if (refuse) return Future<List<AdminBranch>>.error(StateError('500'));
    return Future.value(branches);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

/// شريط «الأكثر طلبًا» والحرارة: العقد الذي لا تملك اللوحة نسخة منه، فيثبّت
/// الاختبار الحرارة بدل الشبكة ويسجّل الفروع التي طُلب منها الشريط.
class _PreviewFake implements CustomerPreviewRepository {
  _PreviewFake({
    this.featured = const [],
    this.temperature,
    this.refuse = false,
  });

  List<PreviewProduct> featured;
  double? temperature;
  bool refuse;

  /// الفروع التي طُلب منها الشريط، بترتيب الطلبات: تبديل الفرع يعيد كل قراءة.
  final List<String?> readBranchIds = <String?>[];

  @override
  Future<List<PreviewProduct>> loadFeatured({
    String? branchId,
    int? limit,
  }) async {
    readBranchIds.add(branchId);
    if (refuse) return Future<List<PreviewProduct>>.error(StateError('500'));
    final cap = limit ?? featured.length;
    return featured.take(cap).toList(growable: false);
  }

  @override
  Future<double> loadTemperature({
    required double latitude,
    required double longitude,
  }) {
    final value = temperature;
    if (value == null) {
      return Future<double>.error(StateError('weather'));
    }
    return Future.value(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

const AdminCategory _iced = AdminCategory(
  id: 'c1',
  nameAr: 'قهوة باردة',
  nameEn: 'Iced',
  slug: 'cold-coffee',
);

const AdminCategory _hot = AdminCategory(
  id: 'c2',
  nameAr: 'سخنات',
  nameEn: 'Hot',
  slug: 'hot-coffee',
);

/// تصنيف موقوف: يقرأه الموظف في شاشته ولا يصل شاشة الزبون.
const AdminCategory _bakery = AdminCategory(
  id: 'c3',
  nameAr: 'مخبوزات',
  nameEn: 'Bakery',
  isActive: false,
);

/// تصنيف «الباقات»: شاشة التصنيفات تعرض له قائمة الباقات لا شبكة المنتجات.
const AdminCategory _bundlesCategory = AdminCategory(
  id: 'c4',
  nameAr: 'باقات',
  nameEn: 'bundles',
  slug: 'bundles',
);

const AdminProduct _latte = AdminProduct(
  id: 'p1',
  nameAr: 'لاتيه مثلج',
  nameEn: 'Iced Latte',
  sku: 'sku-p1',
  slug: 'slug-p1',
  basePrice: 24,
  categoryId: 'c1',
  categoryNameAr: 'قهوة باردة',
  categoryNameEn: 'Iced',
  imageUrl: 'https://example.com/latte.png',
);

const AdminProduct _americano = AdminProduct(
  id: 'p2',
  nameAr: 'أمريكانو',
  nameEn: 'Americano',
  sku: 'sku-p2',
  slug: 'slug-p2',
  basePrice: 18,
  categoryId: 'c1',
  categoryNameAr: 'قهوة باردة',
  categoryNameEn: 'Iced',
);

const AdminProduct _cappuccino = AdminProduct(
  id: 'p4',
  nameAr: 'كابتشينو',
  nameEn: 'Cappuccino',
  sku: 'sku-p4',
  slug: 'slug-p4',
  basePrice: 20,
  categoryId: 'c2',
  categoryNameAr: 'سخنات',
  categoryNameEn: 'Hot',
);

/// منتج موقوف: لا يجوز أن يظهر في المحاكي ولو قرأته اللوحة.
const AdminProduct _retired = AdminProduct(
  id: 'p3',
  nameAr: 'تجربة داخلية',
  nameEn: 'Internal trial',
  sku: 'sku-p3',
  slug: 'slug-p3',
  basePrice: 10,
  categoryId: 'c1',
  isActive: false,
);

const AdminBanner _publishedBanner = AdminBanner(
  id: 'b1',
  titleAr: 'عرض الصباح',
  titleEn: 'Morning offer',
  imageUrl: 'https://example.com/banner.png',
  targetType: 'none',
  sortOrder: 1,
);

const AdminBanner _secondBanner = AdminBanner(
  id: 'b2',
  titleAr: 'عرض المساء',
  titleEn: 'Evening offer',
  imageUrl: 'https://example.com/banner2.png',
  targetType: 'none',
  sortOrder: 2,
);

const AdminBanner _unpublishedBanner = AdminBanner(
  id: 'b3',
  titleAr: 'مسودة عرض',
  titleEn: 'Draft offer',
  imageUrl: 'https://example.com/hidden.png',
  targetType: 'none',
  isPublished: false,
);

/// صفّ شريط «الأكثر طلبًا» بسعره الراجع من القاعدة، باسم لا يتكرر مع أسماء
/// الكتالوج حتى تبقى حواصل الاختبار واحدة.
const PreviewProduct _featuredRow = PreviewProduct(
  id: 'f1',
  nameAr: 'أكثر طلبًا',
  nameEn: 'Best seller',
  categoryAr: 'قهوة باردة',
  categoryEn: 'Iced',
  price: 30,
  oldPrice: 40,
  imageUrl: 'https://example.com/featured.png',
);

const AdminBundle _morningBundle = AdminBundle(
  id: 'bd1',
  nameAr: 'باقة الصباح',
  nameEn: 'Morning bundle',
  bundlePrice: 45,
  components: [
    AdminBundleComponent(productId: 'p1', quantity: 2, basePrice: 20),
    AdminBundleComponent(productId: 'p2', quantity: 1, basePrice: 15),
  ],
);

/// فرع بإحداثيات: الطقس يُقرأ عنه، فالسطر الموسمي يظهر.
const AdminBranch _routed = AdminBranch(
  id: 'br1',
  code: 'R1',
  nameAr: 'فرع الرياض',
  nameEn: 'Riyadh branch',
  address: 'الرياض',
  latitude: 24.7,
  longitude: 46.7,
);

/// فرع بلا إحداثيات: لا طقس، فلا سطر موسمي — كما عند زبون لا يوصل موقعه.
const AdminBranch _blind = AdminBranch(
  id: 'br2',
  code: 'R2',
  nameAr: 'فرع بلا موقع',
  nameEn: 'Unlocated branch',
  address: 'جدة',
);

const AdminCatalogSnapshot _catalog = AdminCatalogSnapshot(
  products: [_latte, _americano, _cappuccino, _retired],
  categories: [_iced, _hot, _bakery],
  total: 137,
  branchId: 'br1',
);

const List<AdminBanner> _liveBanners = [
  _publishedBanner,
  _secondBanner,
  _unpublishedBanner,
];

/// قراءات المعاينة كاملة: بنران وشريطان وباقة وفرع بإحداثيات.
CustomerFeed _fullFeed({double? temperature = 30}) => CustomerFeed(
  banners: _liveBanners,
  categories: const [_iced, _hot, _bakery],
  products: const [_latte, _americano, _cappuccino, _retired],
  featured: const [_featuredRow],
  bundles: const [_morningBundle],
  temperature: temperature,
  now: _now,
);

void _setViewport(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

CustomerPreviewCubit _cubit({
  _CatalogFake? catalog,
  _BannersFake? banners,
  _BundlesFake? bundles,
  _BranchesFake? branches,
  _PreviewFake? preview,
}) {
  return CustomerPreviewCubit(
    catalog: catalog ?? _CatalogFake(snapshot: _catalog),
    banners: banners ?? _BannersFake(banners: _liveBanners),
    bundles: bundles ?? _BundlesFake(bundles: const [_morningBundle]),
    branches: branches ?? _BranchesFake(branches: const [_routed, _blind]),
    preview:
        preview ??
        _PreviewFake(featured: const [_featuredRow], temperature: 30),
  );
}

/// إطار بقياس ثابت: الطريق تعطي ابنها مقاس الشاشة كاملًا، فـ[Align] وحده يترك
/// للـ[SizedBox] مقاسه، وتُقاس عنده الأرقام التي يقيسها العميل.
Widget _box(double width, double height, Widget child) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(width: width, height: height, child: child),
);

/// المحاكي يحمل صورًا شبكية، فحلقة التحميل لا تهدأ؛ تُمرّر بضع إطارات بدل
/// انتظار استقرار كامل. تقليل الحركة مثبّت هنا لأن شريط البنرات وماركيز
/// التصنيفات يمشيان بلا توقف، والاختبار يريد شاشة راكدة لا شاشة تتحرك تحته.
Future<void> _pumpPage(WidgetTester tester, CustomerPreviewCubit cubit) async {
  addTearDown(cubit.close);
  await cubit.load();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: CustomerPreviewPage(cubit: cubit),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// الرئيسية وحدها على شاشة طويلة يكفيها: القائمة تَبني مقاطعها كلها مرة واحدة،
/// فيُقارن ترتيبها وتُلمَس روابطها بلا سحب.
Future<void> _pumpHome(WidgetTester tester, CustomerFeed feed) async {
  _setViewport(tester, 500, 4200);
  const labels = SimulatorLabels(AppLanguage.arabic);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _box(
              AppDimensions.simulatorScreenWidth,
              4200,
              SimulatorHomeScreen(
                feed: feed,
                language: AppLanguage.arabic,
                labels: labels,
                query: '',
                now: _now,
                onSearchChanged: (_) {},
                onSelectCategory: (_) {},
                onSeeAllCategories: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(SimulatorBottomBar),
      matching: find.text(label),
    ),
  );
  await tester.pump();
}

/// شاشة الهاتف قائمة تبنى بقدر ما يسع الهاتف، فما تحت الطيّ لا يُبنى حتى يُسحب.
/// السحب هنا سحب الموظف داخل الهاتف نفسه، فلا تُمرَّر بيانات إلى الشاشة من
/// خارجه ولا تُطوى المقاطع لأجل الاختبار.
Future<void> _scrollHomeTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find
        .descendant(
          of: find.byType(SimulatorHomeScreen),
          matching: find.byType(Scrollable),
        )
        .first,
    const Offset(0, -160),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  group('شاشة العميل داخل الهاتف', () {
    testWidgets('الهاتف يرسم شاشة العميل من بيانات اللوحة نفسها', (
      tester,
    ) async {
      _setViewport(tester, 1280, 900);
      await _pumpPage(tester, _cubit());

      expect(find.text(S.customerPreview), findsOneWidget);
      expect(find.byType(PhoneFrame), findsOneWidget);
      expect(find.byType(SimulatorViewport), findsOneWidget);

      // تحية الصفحة الرئيسية وسؤالها وحبّة بحثها: نصوص تطبيق العميل لا نصوص اللوحة.
      expect(find.text('ماذا تريد اليوم؟'), findsOneWidget);
      expect(find.text('ابحث عن القهوة...'), findsOneWidget);

      // شريط «الأكثر طلبًا» مما رجع به الصف، وشريط الترشيحات من الكتالوج نفسه.
      expect(find.text('أكثر طلبًا'), findsOneWidget);
      expect(find.text('تجربة داخلية'), findsNothing);

      // التصنيف الموقوف لا يصل الهاتف، والنشطان يرسمان دوائره.
      expect(find.text('سخنات'), findsWidgets);
      expect(find.text('مخبوزات'), findsNothing);

      // ترشيحات اليوم تحت الطيّ: تُسحب شاشة الموظف إليها كما يسحب هو.
      await _scrollHomeTo(tester, find.text('أمريكانو'));
      expect(find.text('أمريكانو'), findsOneWidget);
      expect(find.text('ترشيحات لك'), findsOneWidget);
    });

    testWidgets('لا بانر نافذ يترك ملاحظة للموظف مكان المقطع', (tester) async {
      _setViewport(tester, 1280, 900);
      await _pumpPage(tester, _cubit(banners: _BannersFake()));

      expect(find.text('لا بانر منشور في وقته الآن'), findsOneWidget);
    });

    testWidgets('التبويبات السفلية تنقل الشاشة داخل الهاتف', (tester) async {
      _setViewport(tester, 1280, 900);
      await _pumpPage(tester, _cubit());

      await _tapTab(tester, 'التصنيفات');
      expect(find.text('أمريكانو'), findsOneWidget);

      await _tapTab(tester, 'السلة');
      expect(find.text('سلتك فارغة'), findsOneWidget);

      await _tapTab(tester, 'المفضلة');
      expect(find.text('لا توجد مفضلة بعد'), findsOneWidget);

      await _tapTab(tester, 'الإعدادات');
      expect(
        find.text(
          'بيانات هذا التبويب تُقرأ من حساب الزبون على جهازه، ولا تملك اللوحة نسخة منها.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('شاشة التصنيفات تقف على أول تصنيف ثم تتنقل بتبويباتها', (
      tester,
    ) async {
      _setViewport(tester, 1280, 900);
      final cubit = _cubit();
      await _pumpPage(tester, cubit);
      await _tapTab(tester, 'التصنيفات');

      // أول تصنيف نشط هو المعروض بلا ضغط، كما يفعل تطبيق العميل.
      expect(cubit.state.activeCategory?.id, 'c1');
      expect(find.text('لاتيه مثلج'), findsOneWidget);
      expect(find.text('أمريكانو'), findsOneWidget);
      expect(find.text('كابتشينو'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(SimulatorCategoryTabs),
          matching: find.text('سخنات'),
        ),
      );
      await tester.pump();

      expect(cubit.state.activeCategory?.id, 'c2');
      expect(find.text('كابتشينو'), findsOneWidget);
      expect(find.text('لاتيه مثلج'), findsNothing);
    });

    testWidgets('تصنيف الباقات يعرض قائمة الباقات لا شبكة المنتجات', (
      tester,
    ) async {
      _setViewport(tester, 1280, 900);
      final cubit = _cubit(
        catalog: _CatalogFake(
          snapshot: const AdminCatalogSnapshot(
            products: [_latte],
            categories: [_iced, _bundlesCategory],
            branchId: 'br1',
          ),
        ),
      );
      await _pumpPage(tester, cubit);
      await _tapTab(tester, 'التصنيفات');

      await tester.tap(
        find.descendant(
          of: find.byType(SimulatorCategoryTabs),
          matching: find.text('باقات'),
        ),
      );
      await tester.pump();

      expect(cubit.state.activeCategory?.id, 'c4');
      expect(find.text('باقة الصباح'), findsOneWidget);
      expect(find.text('لاتيه مثلج'), findsNothing);
    });

    testWidgets('دائرة التصنيف في الرئيسية تفتح منتجات تصنيفها', (
      tester,
    ) async {
      _setViewport(tester, 1280, 900);
      final cubit = _cubit();
      await _pumpPage(tester, cubit);

      // الماركيز يكرر القائمة ليملأ العرض، فالحلقة الأولى هي ما على الشاشة.
      await tester.tap(
        find
            .descendant(
              of: find.byType(SimulatorCategoryMarquee),
              matching: find.text('سخنات'),
            )
            .first,
      );
      await tester.pump();

      expect(cubit.state.tab, SimulatorTab.categories);
      expect(cubit.state.activeCategory?.id, 'c2');
      expect(find.text('كابتشينو'), findsOneWidget);
    });

    testWidgets('«عرض الكل» في الرئيسية يفتح شاشة التصنيفات', (tester) async {
      _setViewport(tester, 1280, 900);
      final cubit = _cubit();
      await _pumpPage(tester, cubit);

      // العنوان وماركيزه أول ما يسع الهاتف، فالرابط فوقهما مباشرة.
      await tester.tap(find.text('عرض الكل'));
      await tester.pump();

      expect(cubit.state.tab, SimulatorTab.categories);
    });

    testWidgets('الكتابة في حقل البحث تصفّي المنتجات داخل الهاتف', (
      tester,
    ) async {
      _setViewport(tester, 1280, 900);
      await _pumpPage(tester, _cubit());

      await tester.enterText(find.byType(TextField), 'أمريكانو');
      await tester.pump();
      // الحقل نفسه يطبع ما كُتب فيه، فالاسم يُعدّ داخل الشبكة وحدها.
      expect(
        find.descendant(
          of: find.byType(SimulatorProductGrid),
          matching: find.text('أمريكانو'),
        ),
        findsOneWidget,
      );
      expect(find.text('لاتيه مثلج'), findsNothing);
      expect(find.text('نتائج البحث (1)'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'شاي');
      await tester.pump();
      expect(find.text('لا توجد منتجات بعد'), findsOneWidget);
      // الحقل يبقى فوق نتيجته الفارغة: بلاهُ لا سبيل إلى مسح الكلمة من الهاتف.
      expect(find.byType(SimulatorSearchField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('ماذا تريد اليوم؟'), findsOneWidget);
    });

    testWidgets('«عرض المزيد» يفتح صفحة الشريط و«رجوع» يطويها', (tester) async {
      await _pumpHome(tester, _fullFeed());

      await tester.tap(find.text('عرض المزيد').first);
      await tester.pump();

      // صفحة الشريط لا المقاطع: التحية وحبّة البحث خارج الشاشة.
      expect(find.text('أكثر طلبًا'), findsOneWidget);
      expect(find.text('ماذا تريد اليوم؟'), findsNothing);
      expect(find.byType(SimulatorProductGrid), findsOneWidget);

      await tester.tap(find.text('رجوع'));
      await tester.pump();

      expect(find.text('ماذا تريد اليوم؟'), findsOneWidget);
    });

    testWidgets('سحب الهاتف لأسفل يعيد القراءة من اللوحة', (tester) async {
      _setViewport(tester, 1280, 900);
      final catalog = _CatalogFake(snapshot: _catalog);
      await _pumpPage(tester, _cubit(catalog: catalog));

      expect(catalog.loads, 1);
      await tester.drag(find.byType(SimulatorHomeScreen), const Offset(0, 220));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(catalog.loads, 2);
    });

    testWidgets('لغة الهاتف تقلّب تسمياته وحدها', (tester) async {
      _setViewport(tester, 1280, 900);
      await _pumpPage(tester, _cubit());

      await tester.tap(find.text(S.englishLabel));
      await tester.pump();

      expect(find.text('What would you like today?'), findsOneWidget);
      expect(find.text('ماذا تريد اليوم؟'), findsNothing);

      // اسم المنتج نفسه يتبع لغة الهاتف، وهو في شريط تحت الطيّ.
      await _scrollHomeTo(tester, find.text('Iced Latte'));
      expect(find.text('Iced Latte'), findsOneWidget);

      // اللوحة حول الهاتف تبقى بلغتها.
      expect(find.text(S.customerPreview), findsOneWidget);
      expect(find.text(S.previewBannersShown), findsOneWidget);
    });

    testWidgets('الهاتف يصغر حين تضيق اللوحة بدل أن يفيض', (tester) async {
      _setViewport(tester, 520, 700);
      await _pumpPage(tester, _cubit());

      final frame = tester.widget<PhoneFrame>(find.byType(PhoneFrame));
      final size = tester.getSize(find.byType(PhoneFrame));

      expect(frame.width, lessThan(AppDimensions.simulatorScreenWidth));
      expect(size.height, lessThan(700));
      expect(tester.takeException(), isNull);
    });
  });

  group('ما تقرّ به السكة', () {
    testWidgets('السكة تعدّ ما وصل للزبون وتفرّق بينه وبين الكتالوج', (
      tester,
    ) async {
      _setViewport(tester, 1280, 900);
      final cubit = _cubit(
        banners: _BannersFake(
          banners: [
            for (var i = 0; i < 25; i++)
              AdminBanner(
                id: 'b$i',
                titleAr: 'بانر $i',
                titleEn: 'Banner $i',
                imageUrl: 'https://example.com/$i.png',
                targetType: 'none',
                sortOrder: i,
              ),
          ],
        ),
      );
      await _pumpPage(tester, cubit);

      expect(
        cubit.state.feed?.publishedBanners.length,
        CustomerFeed.bannerLimit,
      );
      expect(cubit.state.catalogTotal, 137);
      expect(cubit.state.feed?.catalog.length, 3);
      expect(find.text(S.previewProductsShown), findsOneWidget);
      expect(find.text(S.previewBundlesShown), findsOneWidget);
      expect(find.text(S.previewNotShownTitle), findsOneWidget);
    });

    testWidgets('الفرع المختار يسمّي نفسه والحرارة تُطبع درجة', (tester) async {
      _setViewport(tester, 1280, 900);
      await _pumpPage(tester, _cubit());

      expect(find.text(S.previewBranch), findsOneWidget);
      expect(find.text('فرع الرياض'), findsOneWidget);
      expect(find.text(S.previewWeather), findsOneWidget);
      expect(find.text('${localizeDigits('30')}°'), findsOneWidget);
    });

    testWidgets('فرع بلا إحداثيات يقول لماذا لا طقس', (tester) async {
      _setViewport(tester, 1280, 900);
      await _pumpPage(
        tester,
        _cubit(
          catalog: _CatalogFake(
            snapshot: const AdminCatalogSnapshot(
              products: [_latte],
              categories: [_iced],
              branchId: 'br2',
            ),
          ),
          branches: _BranchesFake(branches: const [_blind]),
        ),
      );

      expect(find.text(S.previewWeatherNoLocation), findsOneWidget);
      expect(find.text(S.previewWeather), findsNothing);
    });

    testWidgets('تبديل الفرع يعيد كل قراءة ولا يترك طقس فرع قديم', (
      tester,
    ) async {
      _setViewport(tester, 1280, 900);
      final preview = _PreviewFake(
        featured: const [_featuredRow],
        temperature: 30,
      );
      final cubit = _cubit(preview: preview);
      await _pumpPage(tester, cubit);

      expect(cubit.state.branchId, 'br1');
      expect(preview.readBranchIds, ['br1']);

      await cubit.selectBranch('br2');
      await tester.pump();

      // الشريط طُلب مرة لكل فرع وقفت عليه الشاشة، والحرارة سقطت لأن الفرع
      // الثاني بلا إحداثيات: لا يبقى سطر موسمي من فرع لا يمثله.
      expect(preview.readBranchIds, ['br1', 'br2']);
      expect(cubit.state.feed?.hasWeather, isFalse);
    });

    testWidgets('مقطع فاشل يُسمّى في السكة وبقية الصفحة تبقى', (tester) async {
      _setViewport(tester, 1280, 900);
      final cubit = _cubit(bundles: _BundlesFake(refuse: true));
      await _pumpPage(tester, cubit);

      expect(cubit.state.degradedSections, ['bundles']);
      expect(
        find.descendant(
          of: find.byType(CustomerPreviewRail),
          matching: find.text(S.bundles),
        ),
        findsOneWidget,
      );
      expect(find.text('ماذا تريد اليوم؟'), findsOneWidget);
      expect(find.byType(SimulatorViewport), findsOneWidget);
    });

    testWidgets('فشل الشريط الموسمي يترك بقية المقاطع', (tester) async {
      _setViewport(tester, 1280, 900);
      final cubit = _cubit(
        preview: _PreviewFake(
          featured: const [_featuredRow],
          temperature: 30,
          refuse: true,
        ),
      );
      await _pumpPage(tester, cubit);

      expect(cubit.state.feed?.featured, isEmpty);
      expect(cubit.state.degradedSections, ['featured']);
      expect(find.text('ماذا تريد اليوم؟'), findsOneWidget);
      // لا عنوان فوق فراغ: مقطع «الأكثر طلبًا» لا يُرسم بلا صفوف.
      expect(find.text('الأكثر طلبًا'), findsNothing);
    });

    testWidgets('تعذّر قراءة الفروع لا يفرغ الهاتف', (tester) async {
      _setViewport(tester, 1280, 900);
      final cubit = _cubit(branches: _BranchesFake(refuse: true));
      await _pumpPage(tester, cubit);

      // بلا فروع لا فرع يُعرف: الأسعار تبقى على أساسها والطقس لا يُقرأ لأحد.
      expect(cubit.state.degradedSections, ['branches']);
      expect(cubit.state.activeBranch, isNull);
      expect(cubit.state.feed?.hasWeather, isFalse);
      expect(find.text('ماذا تريد اليوم؟'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CustomerPreviewRail),
          matching: find.text(S.branches),
        ),
        findsOneWidget,
      );
    });

    testWidgets('القراءة الفاشلة تُظهر رسالة، وإعادة القراءة تنجح', (
      tester,
    ) async {
      _setViewport(tester, 1280, 900);
      final catalog = _CatalogFake(snapshot: _catalog, refuse: true);
      final banners = _BannersFake(refuse: true);
      final cubit = _cubit(catalog: catalog, banners: banners);
      await _pumpPage(tester, cubit);

      expect(find.byType(AdminFailureView), findsOneWidget);
      expect(find.byType(AdminLoadingView), findsNothing);

      await tester.tap(find.text(S.retry));
      await tester.pump();
      await tester.pump();
      expect(find.byType(AdminFailureView), findsOneWidget);

      // نفس الزر بعد أن أصلحت القراءة نفسها: المحاكي يقوم مكان الرسالة.
      catalog.refuse = false;
      banners.refuse = false;
      await tester.tap(find.text(S.retry));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AdminFailureView), findsNothing);
      expect(find.byType(SimulatorViewport), findsOneWidget);
      expect(find.text('ماذا تريد اليوم؟'), findsOneWidget);
    });
  });

  group('مقاطع الرئيسية بترتيب تطبيق العميل', () {
    testWidgets('الترتيب والأرقام: بانر كامل العرض ومقاطع محشوة', (
      tester,
    ) async {
      await _pumpHome(tester, _fullFeed());

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final order = <double>[
        top(find.text('ماذا تريد اليوم؟')),
        top(find.byType(SimulatorSearchField)),
        top(find.byType(SimulatorBannerCarousel)),
        top(find.byType(SimulatorCategoryMarquee)),
        top(find.text('الأكثر طلبًا')),
        top(find.byType(SimulatorPromoBanner)),
        top(find.text('ترشيحات لك')),
        top(find.text('الباقات')),
      ];
      final sorted = <double>[...order]..sort();
      expect(order, sorted);

      // البنر عند العميل كامل العرض، والمقاطع الأخرى داخل حافة المقطع.
      expect(
        tester.getSize(find.byType(SimulatorBannerCarousel)).width,
        AppDimensions.simulatorScreenWidth,
      );
      expect(
        tester.getSize(find.byType(SimulatorCategoryMarquee)).width,
        AppDimensions.simulatorScreenWidth - 2 * AppSpacing.lg,
      );

      // نقطة واحدة لكل بانر نافذ: المخفي لا يشارك في الشريط.
      expect(
        find.descendant(
          of: find.byType(SimulatorBannerCarousel),
          matching: find.byType(AnimatedContainer),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('المقطع الفارغ يختفي مع عنوانه', (tester) async {
      await _pumpHome(tester, _fullFeed());
      expect(find.text('الأكثر طلبًا'), findsOneWidget);

      await _pumpHome(
        tester,
        CustomerFeed(
          banners: const [_publishedBanner],
          categories: const [_iced],
          products: const [_latte],
          now: _now,
        ),
      );

      // لا عنوان فوق فراغ: المقطع كله خارج الشاشة كما عند العميل.
      expect(find.text('الأكثر طلبًا'), findsNothing);
      expect(find.text('الباقات'), findsNothing);
      // بانر واحد لا ثانٍ، فلا بانر فردي.
      expect(find.byType(SimulatorPromoBanner), findsNothing);
    });

    testWidgets('السطر الموسمي يطبع ما يقوله طقس الفرع', (tester) async {
      await _pumpHome(tester, _fullFeed(temperature: 30));
      expect(find.text('اختيارات منعشة ليوم حار'), findsOneWidget);
      expect(find.text('اختيارات دافئة ليوم بارد'), findsNothing);

      await _pumpHome(tester, _fullFeed(temperature: 5));
      expect(find.text('اختيارات دافئة ليوم بارد'), findsOneWidget);

      await _pumpHome(tester, _fullFeed(temperature: null));
      // بلا طقس يبقى المقطع وتختفي التسمية: السبب تقوله السكة لا الشاشة.
      expect(find.text('ترشيحات لك'), findsOneWidget);
      expect(find.text('اختيارات منعشة ليوم حار'), findsNothing);
      expect(find.text('اختيارات دافئة ليوم بارد'), findsNothing);
    });

    testWidgets('التصنيفات الموقوفة لا تصل الماركيز', (tester) async {
      await _pumpHome(tester, _fullFeed());

      expect(
        find.descendant(
          of: find.byType(SimulatorCategoryMarquee),
          matching: find.text('مخبوزات'),
        ),
        findsNothing,
      );
    });
  });

  group('حركة العميل', () {
    testWidgets('شريط البنرات يقلّب نفسه بعد مدة الإمساك', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: _box(
              300,
              300,
              const SimulatorBannerCarousel(
                banners: [_publishedBanner, _secondBanner],
              ),
            ),
          ),
        ),
      );
      final scrollable = find.descendant(
        of: find.byType(PageView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.pixels, 0);

      await tester.pump(SimulatorMotion.carouselHold);
      await tester.pump(const Duration(milliseconds: 300));

      expect(position.pixels, 300);
    });

    testWidgets('شريط ببانر واحد لا مؤقت له', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: _box(
              300,
              300,
              const SimulatorBannerCarousel(banners: [_publishedBanner]),
            ),
          ),
        ),
      );

      // لا مؤقّت يعني لا قلب: بنر واحد يبقى مكانه إلى أن يلمسه الموظف.
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(PageView),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      await tester.pump(SimulatorMotion.carouselHold * 2);
      expect(position.pixels, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('تقليل الحركة يوقف الشريط والماركيز معًا', (tester) async {
      Widget walkable({required bool reduce}) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: _box(
                300,
                600,
                const SimulatorBannerCarousel(
                  banners: [_publishedBanner, _secondBanner],
                ),
              ),
            ),
          ),
        ),
      );
      final scrollable = find.descendant(
        of: find.byType(PageView),
        matching: find.byType(Scrollable),
      );

      await tester.pumpWidget(walkable(reduce: true));
      final held = tester.state<ScrollableState>(scrollable).position;
      await tester.pump(SimulatorMotion.carouselHold * 2);
      expect(held.pixels, 0);

      // نفس الشاشة بحركة مسموحة: المؤقل يعمل والصفحة تتقدم.
      await tester.pumpWidget(walkable(reduce: false));
      final moving = tester.state<ScrollableState>(scrollable).position;
      await tester.pump(SimulatorMotion.carouselHold);
      await tester.pump(const Duration(milliseconds: 300));
      expect(moving.pixels, greaterThan(0));
    });

    testWidgets('ماركيز التصنيفات يمشي ولا ينفد', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: _box(
              200,
              120,
              SimulatorCategoryMarquee(
                categories: const [_iced, _hot],
                language: AppLanguage.arabic,
                onSelect: _noopCategory,
              ),
            ),
          ),
        ),
      );
      final scrollable = find.descendant(
        of: find.byType(SimulatorCategoryMarquee),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;

      await tester.pump(const Duration(seconds: 1));
      expect(position.pixels, greaterThan(0));

      // نسختان من القائمتين على الأقل: الدورة تلف ولا تترك فراغًا.
      expect(position.maxScrollExtent, greaterThan(0));
      expect(
        position.maxScrollExtent,
        greaterThanOrEqualTo(position.viewportDimension),
      );
    });
  });
}

void _noopCategory(AdminCategory category) {}
