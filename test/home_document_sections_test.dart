import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_banner_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_bundles_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_categories_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_document_sections.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/design_section_chrome.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_popular_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_recommendations_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_search_bar.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_single_banner_section.dart';

/// ما يرسمه الهاتف حين ينشر الموظف ترتيب الصفحة.
///
/// الوعد أن المحرّر يحرّك مكوّنات شاشة الزبون نفسها، لا نسخًا منها ولا صناديق
/// عامة: فكل عقدة في المستند تُقرأ هنا باسم المكوّن الذي يخرج من القارئ، لا
/// بشكلها. وعقدة لا يعرفها الهاتف لا تُخترع لها لوحة — تُترك.
void main() {
  testWidgets('هوامش الموضع المنشورة تغيّر موضع عنصر شاشة الزبون', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesignSectionChrome(
            section: PublishedSection(
              id: 'positioned',
              type: DesignWidgetTypes.text,
              properties: const {'marginTop': 24, 'marginLeft': 16},
            ),
            child: const SizedBox(key: Key('positioned-child')),
          ),
        ),
      ),
    );

    expect(
      find.ancestor(
        of: find.byKey(const Key('positioned-child')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == const EdgeInsets.only(top: 24, left: 16),
        ),
      ),
      findsOneWidget,
      reason: 'هوامش المحرر يجب أن تصل إلى غلاف القسم في شاشة الزبون',
    );
  });

  group('عقدة المنشور إلى مكوّن العميل', () {
    test('كل نوع يعرفه الهاتف يعطي مكوّنه الحقيقي', () {
      const expected = <String, Type>{
        DesignWidgetTypes.header: HomeHeader,
        DesignWidgetTypes.searchBar: HomeSearchBar,
        DesignWidgetTypes.bannerCarousel: HomeBannerSection,
        DesignWidgetTypes.categoryList: HomeCategoriesSection,
        DesignWidgetTypes.promoBanner: HomeSingleBannerSection,
        DesignWidgetTypes.bundleList: HomeBundlesSection,
      };
      for (final entry in expected.entries) {
        expect(
          _rendered(buildHomeDocumentSection(_section(entry.key))),
          entry.value,
          reason: 'نوع ${entry.key} لا يرسم مكوّنه في شاشة الزبون.',
        );
      }
    });

    test('خصائص بانرات المعاينة تصل إلى شريط العميل ولا تغيّر المنشور', () {
      final widget = buildHomeDocumentSection(
        PublishedSection(
          id: 'banner-draft',
          type: DesignWidgetTypes.bannerCarousel,
          properties: const {
            'bannerDraftCount': 1,
            'bannerDraft_0_image': 'https://example.invalid/preview.png',
            'bannerDraft_0_targetType': 'product',
            'bannerDraft_0_targetId': 'product-1',
          },
        ),
      );

      final carousel = _unwrap(widget) as HomeBannerSection;
      expect(carousel.previewBanners, hasLength(1));
      expect(
        carousel.previewBanners!.single.image,
        'https://example.invalid/preview.png',
      );
      expect(carousel.previewBanners!.single.target.storage, 'product');
      expect(carousel.previewBanners!.single.targetId, 'product-1');

      final regular = _unwrap(
        buildHomeDocumentSection(_section(DesignWidgetTypes.bannerCarousel)),
      ) as HomeBannerSection;
      expect(regular.previewBanners, isNull);
    });

    test('عناوين أقسام المتجر المخصصة تصل إلى مكوّناتها الحقيقية', () {
      final category = buildHomeDocumentSection(
        PublishedSection(
          id: 'categories',
          type: DesignWidgetTypes.categoryList,
          properties: const {
            'title_ar': 'اختياراتنا',
            'title_en': 'Our categories',
          },
        ),
      );
      expect(_rendered(category), HomeCategoriesSection);
      expect((_unwrap(category) as HomeCategoriesSection).title, 'اختياراتنا');

      final featured = buildHomeDocumentSection(
        PublishedSection(
          id: 'featured',
          type: DesignWidgetTypes.productStrip,
          dataSource: DesignDataSources.featured,
          properties: const {'title_ar': 'الأكثر مبيعًا'},
        ),
      );
      expect((_unwrap(featured) as HomePopularSection).title, 'الأكثر مبيعًا');

      final bundles = buildHomeDocumentSection(
        PublishedSection(
          id: 'bundles',
          type: DesignWidgetTypes.bundleList,
          properties: const {'title_en': 'Coffee bundles'},
        ),
      );
      expect((_unwrap(bundles) as HomeBundlesSection).title, 'Coffee bundles');
    });

    test('شريطا المنتجات نوع واحد والفصل بمصدر البيانات وحده', () {
      expect(
        _rendered(
          buildHomeDocumentSection(
            _section(
              DesignWidgetTypes.productStrip,
              dataSource: DesignDataSources.featured,
            ),
          ),
        ),
        HomePopularSection,
      );
      expect(
        _rendered(
          buildHomeDocumentSection(
            _section(
              DesignWidgetTypes.productStrip,
              dataSource: DesignDataSources.recommendations,
            ),
          ),
        ),
        HomeRecommendationsSection,
      );
      // مصدر لا يعرفه الهاتف — ولا مصدر أصلًا — لا يُختار له شريط: تخمين
      // أحدهما يخلط ترشيحات الزبون بصفّ الأكثر مبيعًا.
      expect(
        buildHomeDocumentSection(
          _section(
            DesignWidgetTypes.productStrip,
            dataSource: 'catalog.newest',
          ),
        ),
        isNull,
      );
      expect(
        buildHomeDocumentSection(_section(DesignWidgetTypes.productStrip)),
        isNull,
      );
    });

    test('الإخفاء قرار ظاهر، والنوع المجهول لا يستبدل بصندوق', () {
      expect(
        buildHomeDocumentSection(
          _section(DesignWidgetTypes.header, visible: false),
        ),
        isNull,
      );
      expect(
        buildHomeDocumentSection(_section('section.countdown_timer')),
        isNull,
      );
      // جذر الصفحة نوعٌ في المستند لا قسمٌ على الشاشة: لا يُرسم منه صندوق.
      expect(
        buildHomeDocumentSection(_section(DesignWidgetTypes.pageHome)),
        isNull,
      );
    });

    test('القائمة تحفظ الترتيب وتسقط ما لا يُرسم', () {
      final sections = buildHomeDocumentSections(<PublishedSection>[
        _section(DesignWidgetTypes.header),
        _section('section.loyalty_wheel'),
        _section(DesignWidgetTypes.bannerCarousel, visible: false),
        _section(
          DesignWidgetTypes.productStrip,
          dataSource: DesignDataSources.recommendations,
        ),
        _section(DesignWidgetTypes.searchBar),
      ]);

      expect(sections.map(_rendered).toList(), <Type>[
        HomeHeader,
        HomeRecommendationsSection,
        HomeSearchBar,
      ]);
    });
  });

  group('المستند المنشور إلى أقسام الصفحة الرئيسية', () {
    test('جذر page.home يعطي أبناءه بترتيبهم المنشور', () {
      final design = PublishedDesign.fromJson(
        _document(<Map<String, Object?>>[
          _node('a', DesignWidgetTypes.header),
          _node('b', DesignWidgetTypes.searchBar),
          _node('c', DesignWidgetTypes.bannerCarousel),
          _node('d', DesignWidgetTypes.categoryList),
          _node(
            'e',
            DesignWidgetTypes.productStrip,
            dataSource: DesignDataSources.featured,
          ),
          _node('f', DesignWidgetTypes.promoBanner),
          _node(
            'g',
            DesignWidgetTypes.productStrip,
            dataSource: DesignDataSources.recommendations,
          ),
          _node('h', DesignWidgetTypes.bundleList),
        ]),
      );

      expect(design, isNotNull);
      expect(
        design!.homeSections.map((section) => section.id).toList(),
        <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'],
      );
      // النشر الذي لم يمس شيئًا يرسم ترتيب اليوم حرفيًا.
      expect(
        buildHomeDocumentSections(design.homeSections).map(_rendered).toList(),
        _todaysHomeOrder,
        reason: 'المستند الافتراضي المنشور لا يغيّر شاشة الزبون — الوعد الأول.',
      );
      expect(design.theme.isNeutral, isTrue);
      expect(design.schemaVersion, 2);
    });

    test('لا صفحة رئيسية، أو جذر ليس صفحتها، أو ابن بلا نوع', () {
      expect(
        PublishedDesign.fromJson(<String, Object?>{
          'schema_version': 2,
          'pages': <Object?>[],
        })!.homeSections,
        isEmpty,
      );
      // صفحة أخرى في المستند لا تمسّ الرئيسية: أقسامها لها.
      expect(
        PublishedDesign.fromJson(<String, Object?>{
          'schema_version': 2,
          'pages': <Object?>[
            <String, Object?>{
              'page': 'categories',
              'root': _rootNode(<Object?>[
                _node('x', DesignWidgetTypes.header),
              ]),
            },
          ],
        })!.homeSections,
        isEmpty,
      );
      // جذر لا نوعه `page.home` ليس صفحة رئيسية معروفة.
      expect(
        PublishedDesign.fromJson(<String, Object?>{
          'schema_version': 2,
          'pages': <Object?>[
            <String, Object?>{
              'page': 'home',
              'root': <String, Object?>{
                'id': 'root',
                'type': 'column',
                'children': <Object?>[_node('x', DesignWidgetTypes.header)],
              },
            },
          ],
        })!.homeSections,
        isEmpty,
      );
      // الابن بلا نوع ليس قسمًا: يسقط وحده، ولا يُهجر المستند لأجله.
      final design = PublishedDesign.fromJson(
        _document(<Map<String, Object?>>[
          _node('keep', DesignWidgetTypes.header),
          <String, Object?>{'id': 'broken', 'type': '', 'visible': true},
        ]),
      );
      expect(
        design!.homeSections.map((section) => section.id).toList(),
        <String>['keep'],
      );
    });

    test('مخطط أحدث لا يُقرأ، و1 بلا أقسام يعمل', () {
      final pages = _document(<Map<String, Object?>>[
        _node('a', DesignWidgetTypes.header),
      ])['pages'];
      expect(
        PublishedDesign.fromJson(<String, Object?>{
          'schema_version': 3,
          'pages': pages,
        }),
        isNull,
      );
      expect(
        PublishedDesign.fromJson(<String, Object?>{
          'schema_version': 1,
          'pages': pages,
        })!.homeSections.map((section) => section.id).toList(),
        <String>['a'],
      );
    });
  });

  group('المحتوى الحر في المستند المنشور', () {
    testWidgets('نص مكتمل الخصائص يرسم نصه وصفّه وحجمه', (tester) async {
      await _pumpHome(tester, [
        _node(
          't1',
          DesignWidgetTypes.text,
          properties: {
            'text': 'أهلًا بك',
            'size': 16,
            'weight': 'bold',
            'alignment': 'center',
          },
        ),
      ]);
      expect(find.text('أهلًا بك'), findsOneWidget);
    });

    testWidgets('localized headings and text follow the selected language', (
      tester,
    ) async {
      final previousLanguage = AppLocale.instance.language;
      addTearDown(() => AppLocale.instance.debugSet(previousLanguage));

      AppLocale.instance.debugSet(AppLanguage.english);
      await _pumpHome(tester, [
        _node(
          'heading',
          DesignWidgetTypes.heading,
          properties: {
            'title_ar': 'عنوان عربي',
            'title_en': 'English heading',
            'subtitle_ar': 'وصف عربي',
            'subtitle_en': 'English subtitle',
          },
        ),
        _node(
          'text',
          DesignWidgetTypes.text,
          properties: {'text_ar': 'نص عربي', 'text_en': 'English text'},
        ),
      ]);
      expect(find.text('English heading'), findsOneWidget);
      expect(find.text('English subtitle'), findsOneWidget);
      expect(find.text('English text'), findsOneWidget);
      expect(find.text('عنوان عربي'), findsNothing);

      AppLocale.instance.debugSet(AppLanguage.arabic);
      await _pumpHome(tester, [
        _node(
          'heading',
          DesignWidgetTypes.heading,
          properties: {
            'title_ar': 'عنوان عربي',
            'title_en': 'English heading',
            'subtitle_ar': 'وصف عربي',
            'subtitle_en': 'English subtitle',
          },
        ),
        _node(
          'text',
          DesignWidgetTypes.text,
          properties: {'text_ar': 'نص عربي', 'text_en': 'English text'},
        ),
      ]);
      expect(find.text('عنوان عربي'), findsOneWidget);
      expect(find.text('وصف عربي'), findsOneWidget);
      expect(find.text('نص عربي'), findsOneWidget);
      expect(find.text('English heading'), findsNothing);
    });

    testWidgets('اتجاه الكتابة وتباعد الحروف وقصّ النص تصل إلى العميل', (
      tester,
    ) async {
      await _pumpHome(tester, [
        _node(
          'styled',
          DesignWidgetTypes.text,
          properties: {
            'text': 'نص بتنسيق قابل للتحكم',
            'textDirection': 'ltr',
            'letterSpacing': 2.5,
            'overflow': 'fade',
            'maxLines': 1,
          },
        ),
      ]);

      final text = tester.widget<Text>(find.text('نص بتنسيق قابل للتحكم'));
      expect(text.textDirection, TextDirection.ltr);
      expect(text.style!.letterSpacing, 2.5);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.fade);
    });

    testWidgets('نص بلا خصائص لا يرسم شيئًا', (tester) async {
      await _pumpHome(tester, [_node('t2', DesignWidgetTypes.text)]);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('فاصل يرسم فاصلًا، ومسافة ترسم ارتفاعها', (tester) async {
      await _pumpHome(tester, [
        _node('d1', DesignWidgetTypes.divider),
        _node('s1', DesignWidgetTypes.spacer, properties: {'size': 'xl'}),
      ]);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('عمود يرسم أبناءه بترتيبهم المنشور', (tester) async {
      await _pumpHome(tester, [
        _nestedNode('c1', DesignWidgetTypes.column, <Object?>[
          _node('t1', DesignWidgetTypes.text, properties: {'text': 'اول'}),
          _node('t2', DesignWidgetTypes.text, properties: {'text': 'ثاني'}),
        ]),
      ]);
      expect(find.text('اول'), findsOneWidget);
      expect(find.text('ثاني'), findsOneWidget);
    });

    testWidgets('عمود فارغ أو بلا أبناء يرسمين لا يرسم', (tester) async {
      await _pumpHome(tester, [_node('c2', DesignWidgetTypes.column)]);
      expect(find.byType(Text), findsNothing);
    });

    test('عمود بابن حقيقي يرسم ابنه الحقيقي لا بديلًا', () {
      // عمود يحمل شريط بانر: الشريط نفسه، لا صندوق بديل.
      final column = PublishedSection.fromJson(
        _nestedNode('c3', DesignWidgetTypes.column, <Object?>[
          _node('b1', DesignWidgetTypes.bannerCarousel),
        ]),
      )!;
      expect(
        _rendered(buildHomeDocumentSection(column.children.first)),
        HomeBannerSection,
      );
    });

    test('شبكة منتجات بمصدر مجهول لا تُرسم ولا تُخمّن', () {
      expect(
        buildHomeDocumentSection(
          _section(
            DesignWidgetTypes.productGrid,
            dataSource: 'categoryProducts',
          ),
        ),
        isNotNull,
        reason: 'مكوّن الشبكة يُرسم ثم يفرغ داخله؛ المصدر المجهول صف لا شيء',
      );
    });

    test('الخصائص والأبناء تحفظ في التسلسل الراجع', () {
      final design = PublishedDesign.fromJson(
        _document([
          _nestedNode('c1', DesignWidgetTypes.column, <Object?>[
            _node('t1', DesignWidgetTypes.text, properties: {'text': 'سطر'}),
          ]),
        ]),
      );
      final roundTrip = PublishedDesign.fromJson(design!.toDocument())!;
      final column = roundTrip.homeSections.single;
      expect(column.type, DesignWidgetTypes.column);
      expect(column.children.single.property('text'), 'سطر');
    });
  });
}

/// ترتيب الصفحة كما يرسمه الهاتف اليوم، بلا مستند.
///
/// هو المرجع الذي لا يتحرك: حرس التطابق في `home_section_order_parity_test.dart`
/// يربطه بالمستند الافتراضي في اللوحة، وهذا الاختبار يربطه بما يرسمه قارئ
/// المستند — فالدائرة مغلقة من نص المصدر إلى شاشة الزبون.
const List<Type> _todaysHomeOrder = <Type>[
  HomeHeader,
  HomeSearchBar,
  HomeBannerSection,
  HomeCategoriesSection,
  HomePopularSection,
  HomeSingleBannerSection,
  HomeRecommendationsSection,
  HomeBundlesSection,
];

PublishedSection _section(
  String type, {
  String? dataSource,
  bool visible = true,
}) => PublishedSection(
  id: 'home_$type',
  type: type,
  visible: visible,
  dataSource: dataSource,
);

/// الصنف الذي يرسمه القسم: [HomeSection] غلاف الحشو حول القسم فيُفتح إلى ما
/// داخله، والشريط الكامل الحشو يرسم نفسه بلا غلاف.
Type _rendered(Widget? widget) => _unwrap(widget).runtimeType;

Widget _unwrap(Widget? widget) {
  expect(widget, isNotNull, reason: 'القسم لم يُرسم أصلًا.');
  Widget inner = widget!;
  while (true) {
    if (inner is HomeSection) {
      inner = inner.child;
    } else if (inner is DesignSectionChrome) {
      inner = inner.child;
    } else {
      return inner;
    }
  }
}

/// عقدة كما تخرج من `DesignNode.toMap()` في اللوحة.
Map<String, Object?> _node(
  String id,
  String type, {
  String? dataSource,
  bool visible = true,
  Map<String, Object?>? properties,
}) => <String, Object?>{
  'id': id,
  'type': type,
  'visible': visible,
  'properties': <String, Object?>{'dataSource': ?dataSource, ...?properties},
  'children': <Object?>[],
};

/// عقدة بأبناء: عمودًا أو غيره.
Map<String, Object?> _nestedNode(
  String id,
  String type,
  List<Object?> children,
) => <String, Object?>{..._node(id, type), 'children': children};

/// ضخ أقسام المستند في شاشة حقيقية: الرسم الكامل لا الاستدعاء الجاف،
/// فالمحرّك قد يبدأ ويدرك أن لا شيء يرسم.
Future<void> _pumpHome(
  WidgetTester tester,
  List<Map<String, Object?>> nodes,
) async {
  final design = PublishedDesign.fromJson(_document(nodes))!;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: buildHomeDocumentSections(design.homeSections),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Map<String, Object?> _rootNode(List<Object?> children) => <String, Object?>{
  'id': 'home_root',
  'type': DesignWidgetTypes.pageHome,
  'visible': true,
  'properties': <String, Object?>{},
  'children': children,
};

/// مستند بشكل ما تنشره اللوحة: صفحة رئيسية واحدة جذرها `page.home`.
Map<String, Object?> _document(List<Map<String, Object?>> sections) =>
    <String, Object?>{
      'schema_version': 2,
      'pages': <Object?>[
        <String, Object?>{'page': 'home', 'root': _rootNode(sections)},
      ],
    };
