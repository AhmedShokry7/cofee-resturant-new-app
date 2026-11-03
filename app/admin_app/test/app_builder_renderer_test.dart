import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/domain/registry/action_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/data_source_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/design_renderer.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/design_simulator_screen.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_banner_carousel.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_category_marquee.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_category_tabs.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_home_header.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_no_banner_note.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_notice_screen.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_card.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_details_screen.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_grid.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_strip.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_promo_banner.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_search_field.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';

/// زمن وثوابت مقاس: الشاشة تُقاس بارتفاع هاتف، والمقطع الذي لا يدخلها لا يُبنى.
final _now = DateTime.utc(2026, 11, 3, 12);

PreviewProduct _row(String id, {double? oldPrice}) => PreviewProduct(
  id: id,
  nameAr: 'قهوة $id',
  nameEn: 'Coffee $id',
  price: 25,
  oldPrice: oldPrice,
);

AdminBanner _banner(String id) => AdminBanner(
  id: id,
  titleAr: 'بانر $id',
  titleEn: 'Banner $id',
  imageUrl: 'https://example.com/$id.png',
  targetType: 'none',
  sortOrder: 0,
  isPublished: true,
);

CustomerFeed _feed({
  List<AdminBanner> banners = const [],
  List<AdminCategory> categories = const [_c1],
  List<AdminProduct> products = const [_p1, _p2],
  List<PreviewProduct> featured = const [],
  double? temperature,
}) => CustomerFeed(
  banners: banners,
  categories: categories,
  products: products,
  featured: featured,
  temperature: temperature,
  now: _now,
);

const AdminCategory _c1 = AdminCategory(
  id: 'c1',
  nameAr: 'تصنيف c1',
  nameEn: 'Category c1',
  isActive: true,
  slug: 'hot-coffee',
);

const AdminProduct _p1 = AdminProduct(
  id: 'p1',
  nameAr: 'قهوة p1',
  nameEn: 'Coffee p1',
  sku: 'sku-p1',
  slug: 'slug-p1',
  basePrice: 20,
  categoryId: 'c1',
  isActive: true,
  isDraft: false,
);

const AdminProduct _p2 = AdminProduct(
  id: 'p2',
  nameAr: 'قهوة p2',
  nameEn: 'Coffee p2',
  sku: 'sku-p2',
  slug: 'slug-p2',
  basePrice: 24,
  categoryId: 'c1',
  isActive: true,
  isDraft: false,
);

/// رئيسية اختبار بجذرها ومقاطعها، وبقية صفحات المستند من السجل كما يفتحها
/// المحرّر أول مرة: لا جذر مُختَرع لكل اختبار.
DesignDocument _home(List<DesignNode> sections) =>
    WidgetRegistry.defaultDocument().withPage(
      AppPage.home,
      WidgetRegistry.node(WidgetTypes.pageHome, 'home', children: sections),
    );

/// صفحة راكدة بارتفاع هاتف: الحركة مطفأة لأن شريط البنرات وماركيز التصنيفات
/// يمشيان بلا توقف، والاختبار يريد شاشة ثابتة لا شاشة تتحرك تحته.
Widget _screen({
  required DesignDocument document,
  AppPage page = AppPage.home,
  CustomerFeed? feed,
  String query = '',
  String? categoryId,
  ValueChanged<AppPage>? onNavigate,
  ValueChanged<String>? onSelectCategory,
  ValueChanged<String>? onSearchChanged,
  DesignNodeDecorator? decorate,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,
            height: 844,
            child: _Host(
              document: document,
              page: page,
              feed: feed ?? _feed(),
              query: query,
              categoryId: categoryId,
              onNavigate: onNavigate,
              onSelectCategory: onSelectCategory,
              onSearchChanged: onSearchChanged,
              decorate: decorate,
            ),
          ),
        ),
      ),
    ),
  );
}

/// الوسيط الذي يمسك ما تمسكه حالة المحاكي: اللغة والتسميات والوقت — وهي عند
/// اللوحة، لا داخل الشاشة — ثم يمرّرها للشاشة كما يمرّرها جوف الهاتف.
class _Host extends StatelessWidget {
  const _Host({
    required this.document,
    required this.page,
    required this.feed,
    required this.query,
    this.categoryId,
    this.onNavigate,
    this.onSelectCategory,
    this.onSearchChanged,
    this.decorate,
  });

  final DesignDocument document;
  final AppPage page;
  final CustomerFeed feed;
  final String query;
  final String? categoryId;
  final ValueChanged<AppPage>? onNavigate;
  final ValueChanged<String>? onSelectCategory;
  final ValueChanged<String>? onSearchChanged;
  final DesignNodeDecorator? decorate;

  @override
  Widget build(BuildContext context) {
    const language = AppLanguage.arabic;
    return DesignSimulatorScreen(
      document: document,
      page: page,
      feed: feed,
      language: language,
      labels: const SimulatorLabels(language),
      now: _now,
      query: query,
      categoryId: categoryId,
      onSearchChanged: onSearchChanged ?? (_) {},
      onSelectCategory: onSelectCategory ?? (_) {},
      onNavigate: onNavigate ?? (_) {},
      decorate: decorate,
    );
  }
}

void main() {
  group('الرسم من المستند', () {
    testWidgets('التصميم الافتراضي يبني الرئيسية بمقاطعها الحقيقية بترتيبها', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          document: WidgetRegistry.defaultDocument(),
          feed: _feed(
            banners: [_banner('b1'), _banner('b2')],
            categories: [_c1],
            featured: [_row('f1')],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      double top(Type widget) => tester.getTopLeft(find.byType(widget)).dy;
      expect(top(SimulatorHomeHeader), lessThan(top(SimulatorSearchField)));
      expect(top(SimulatorSearchField), lessThan(top(SimulatorBannerCarousel)));
      expect(
        top(SimulatorBannerCarousel),
        lessThan(top(SimulatorCategoryMarquee)),
      );
      expect(find.byType(SimulatorProductStrip), findsOneWidget);
      expect(find.byType(SimulatorNoticeScreen), findsNothing);

      // الشبكة نزولية البناء، فأسفل الطية لا يُبنى إلا بعد سحب — كما في هاتف
      // الزبون: المقاطع السبعة في المستند لا تُرى كلها مرة واحدة.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(SimulatorProductStrip), findsNWidgets(2));
      expect(find.byType(SimulatorPromoBanner), findsOneWidget);
      expect(find.text('الأكثر طلبًا'), findsOneWidget);
      expect(find.text('ترشيحات لك'), findsOneWidget);
    });

    testWidgets('مقطع بلا صفوف يختفي، والبنر وحده يترك سطرًا للموظف', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          document: _home(<DesignNode>[
            WidgetRegistry.node(WidgetTypes.bannerCarousel, 'home_banners'),
            WidgetRegistry.node(
              WidgetTypes.productStrip,
              'home_popular',
              overrides: const <String, Object?>{'title': 'الأكثر طلبًا'},
            ),
          ]),
          feed: _feed(featured: const <PreviewProduct>[]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(SimulatorNoBannerNote), findsOneWidget);
      expect(find.byType(SimulatorProductStrip), findsNothing);
    });

    testWidgets('showPrice تُقرأ عند الرسم لا في قائمة الخصائص فقط', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          document: _home(<DesignNode>[
            WidgetRegistry.node(
              WidgetTypes.productStrip,
              'home_no_price',
              overrides: const <String, Object?>{
                'dataSource': DataSourceRegistry.products,
                'showPrice': false,
                'title': 'بلا أسعار',
              },
            ),
            WidgetRegistry.node(
              WidgetTypes.productStrip,
              'home_with_price',
              overrides: const <String, Object?>{
                'dataSource': DataSourceRegistry.products,
                'title': 'بأسعار',
              },
            ),
          ]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      // أربع بطاقات على الشاشة، وسطران منها فقط يطبعان السعر.
      expect(find.byType(SimulatorProductCard), findsNWidgets(4));
      expect(
        find.descendant(
          of: find.byType(SimulatorProductStrip),
          matching: find.byType(AdminMoneyText),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('autoplay وradius يبلّغان شريط البنرات', (tester) async {
      await tester.pumpWidget(
        _screen(
          document: _home(<DesignNode>[
            WidgetRegistry.node(
              WidgetTypes.bannerCarousel,
              'home_banners',
              overrides: const <String, Object?>{
                'autoplay': false,
                'radius': 'lg',
              },
            ),
          ]),
          feed: _feed(banners: [_banner('b1')]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      final carousel = tester.widget<SimulatorBannerCarousel>(
        find.byType(SimulatorBannerCarousel),
      );
      expect(carousel.autoplay, isFalse);
      expect(carousel.radius, AppRadius.lg);
    });

    testWidgets('سطر الترشيحات الموسمي مع قراءة الطقس وحدها', (tester) async {
      Widget page(CustomerFeed feed) => _screen(
        document: _home(<DesignNode>[
          WidgetRegistry.node(
            WidgetTypes.productStrip,
            'home_recommendations',
            overrides: const <String, Object?>{
              'dataSource': DataSourceRegistry.recommendations,
              'title': 'ترشيحات لك',
            },
          ),
        ]),
        feed: feed,
      );

      await tester.pumpWidget(page(_feed(temperature: 38)));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('اختيارات دافئة ليوم بارد'), findsNothing);
      expect(find.text('اختيارات منعشة ليوم حار'), findsOneWidget);

      await tester.pumpWidget(page(_feed()));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('اختيارات منعشة ليوم حار'), findsNothing);
    });
  });

  group('التنقل داخل الهاتف', () {
    testWidgets('«عرض المزيد» يفتح كل صفوف الشريط وشبكته بلا سقف', (
      tester,
    ) async {
      final rows = <PreviewProduct>[
        for (var index = 1; index <= 5; index++) _row('f$index'),
      ];
      await tester.pumpWidget(
        _screen(
          document: _home(<DesignNode>[
            WidgetRegistry.node(
              WidgetTypes.productStrip,
              'home_popular',
              overrides: const <String, Object?>{
                'title': 'الأكثر طلبًا',
                'linkLabel': 'عرض المزيد',
                'action': ActionRegistry.seeAllProducts,
                'maxItems': 2,
              },
            ),
          ]),
          feed: _feed(featured: rows),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(SimulatorProductCard), findsNWidgets(2));
      expect(find.text('قهوة f5'), findsNothing);

      await tester.tap(find.text('عرض المزيد'));
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(SimulatorProductGrid), findsOneWidget);
      expect(find.text('الأكثر طلبًا'), findsOneWidget);

      // الشبكة تُبنى نزولًا، فآخر الخمسة لا يظهر قبل السحب.
      await tester.drag(
        find.byType(SimulatorProductGrid),
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('قهوة f5'), findsOneWidget);

      await tester.tap(find.text('رجوع'));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(SimulatorProductGrid), findsNothing);
      expect(find.byType(SimulatorProductCard), findsNWidgets(2));
    });

    testWidgets('الكتابة في الحقل تنقل الشاشة إلى صفحة البحث بنتائجها', (
      tester,
    ) async {
      final typed = <String>[];
      await tester.pumpWidget(
        _screen(
          document: WidgetRegistry.defaultDocument(),
          onSearchChanged: typed.add,
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      await tester.enterText(find.byType(TextField), 'p2');
      await tester.pump(const Duration(milliseconds: 120));
      expect(typed, <String>['p2']);

      // الحالة عند اللوحة، لا داخل الشاشة: إعادة البناء بالسؤال الجديد هي ما
      // يراه الزبون.
      await tester.pumpWidget(
        _screen(
          document: WidgetRegistry.defaultDocument(),
          query: 'p2',
          onSearchChanged: typed.add,
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('قهوة p2'), findsOneWidget);
      expect(find.text('قهوة p1'), findsNothing);
      expect(find.text('نتائج البحث (1)'), findsOneWidget);
      expect(find.byType(SimulatorSearchField), findsOneWidget);
    });

    testWidgets('إجراء فتح المنتج يفتح تفاصيله والرجوع يعود', (tester) async {
      await tester.pumpWidget(
        _screen(
          document: _home(<DesignNode>[
            WidgetRegistry.node(
              WidgetTypes.button,
              'home_open',
              overrides: const <String, Object?>{
                'label': 'افتح المنتج',
                'action': ActionRegistry.openProduct,
                'productId': 'p1',
              },
            ),
          ]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      await tester.tap(find.text('افتح المنتج'));
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(SimulatorProductDetailsScreen), findsOneWidget);
      expect(find.text('قهوة p1'), findsOneWidget);
      expect(
        find.text(
          'الخيارات والسلة تخصّان حساب الزبون على جهازه، ولا تفتحهما اللوحة.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('رجوع'));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(SimulatorProductDetailsScreen), findsNothing);
    });

    testWidgets('إجراء التنقل يبلّغ اللوحة بالصفحة المقصودة', (tester) async {
      final visited = <AppPage>[];
      await tester.pumpWidget(
        _screen(
          document: _home(<DesignNode>[
            WidgetRegistry.node(
              WidgetTypes.heading,
              'home_heading',
              overrides: const <String, Object?>{
                'title': 'التصنيفات',
                'linkLabel': 'اذهب',
                'action': ActionRegistry.navigateCategories,
              },
            ),
          ]),
          onNavigate: visited.add,
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      await tester.tap(find.text('اذهب'));
      await tester.pump(const Duration(milliseconds: 120));
      expect(visited, <AppPage>[AppPage.categories]);
    });

    testWidgets('الضغط على تصنيف يبلغ اللوحة بمعرّفه', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(
        _screen(
          document: _home(<DesignNode>[
            WidgetRegistry.node(WidgetTypes.categoryList, 'home_categories'),
          ]),
          onSelectCategory: picked.add,
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      await tester.tap(find.text('تصنيف c1'));
      await tester.pump(const Duration(milliseconds: 120));
      expect(picked, <String>['c1']);
    });

    testWidgets('صفحة التصنيفات تُرسم من مستندها: تبويباتها ثم شبكة تصنيفها', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          document: WidgetRegistry.defaultDocument(),
          page: AppPage.categories,
          categoryId: 'c1',
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(SimulatorCategoryTabs), findsOneWidget);
      expect(find.text('قهوة p1'), findsOneWidget);
      expect(find.text('قهوة p2'), findsOneWidget);
    });

    testWidgets('تبديل التبويب يُغلق الشاشات المفتوحة فوق الصفحة', (
      tester,
    ) async {
      final document = WidgetRegistry.defaultDocument();
      await tester.pumpWidget(
        _screen(
          document: document,
          feed: _feed(
            featured: <PreviewProduct>[
              for (var index = 1; index <= 5; index++) _row('f$index'),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.text('عرض المزيد'));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(SimulatorProductGrid), findsOneWidget);

      await tester.pumpWidget(
        _screen(document: document, page: AppPage.categories, categoryId: 'c1'),
      );
      await tester.pump(const Duration(milliseconds: 120));
      // شاشة المستند المفتوحة خلفها، والتصنيفات كما هي: تبويباتها ثم شبكة
      // تصنيفها بلا عنوان «رجوع».
      expect(find.text('رجوع'), findsNothing);
      expect(find.byType(SimulatorCategoryTabs), findsOneWidget);
      expect(find.text('قهوة p1'), findsOneWidget);
    });

    testWidgets('صفحة لا جذر لها في المستند تقول ذلك بلا صفوف', (tester) async {
      await tester.pumpWidget(
        _screen(
          document: DesignDocument(
            schemaVersion: WidgetRegistry.schemaVersion,
            pages: <AppPage, DesignNode>{
              AppPage.home: WidgetRegistry.node(WidgetTypes.pageHome, 'home'),
            },
          ),
          page: AppPage.categories,
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(SimulatorNoticeScreen), findsOneWidget);
      expect(find.text('لا تصميم محفوظ لهذه الصفحة بعد'), findsOneWidget);
    });
  });

  group('اللوحة والزبون من نفس الشجرة', () {
    testWidgets('العقدة المخفية لا تصل للزبون وتصل للوحة', (tester) async {
      final document = _home(<DesignNode>[
        WidgetRegistry.node(
          WidgetTypes.text,
          'home_note',
          overrides: const <String, Object?>{'text': 'تنبيه للموظف'},
        ).copyWith(isVisible: false),
      ]);

      await tester.pumpWidget(_screen(document: document));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('تنبيه للموظف'), findsNothing);

      await tester.pumpWidget(
        _screen(
          document: document,
          // اللوحة تلفّ كل عقدة بحدودها، فتبقى المخفية مرئية فيها ليُعاد
          // إظهارها من الشجرة.
          decorate: (context, node, child) =>
              KeyedSubtree(key: ValueKey('canvas-${node.id}'), child: child),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('تنبيه للموظف'), findsOneWidget);
      expect(find.byKey(const ValueKey('canvas-home_note')), findsOneWidget);
    });

    testWidgets('نوع لا يعرفه السجل لا يرسم شيئًا', (tester) async {
      await tester.pumpWidget(
        _screen(
          document: _home(<DesignNode>[
            DesignNode(id: 'home_ghost', type: 'section.not_registered'),
            WidgetRegistry.node(WidgetTypes.header, 'home_header'),
          ]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(SimulatorHomeHeader), findsOneWidget);
    });
  });
}
