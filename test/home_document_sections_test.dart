import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_banner_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_bundles_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_categories_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_document_sections.dart';
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

      expect(
        sections.map(_rendered).toList(),
        <Type>[HomeHeader, HomeRecommendationsSection, HomeSearchBar],
      );
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
        })!
            .homeSections,
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
        })!
            .homeSections,
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
        })!
            .homeSections,
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
        })!
            .homeSections
            .map((section) => section.id)
            .toList(),
        <String>['a'],
      );
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
Type _rendered(Widget? widget) {
  expect(widget, isNotNull, reason: 'القسم لم يُرسم أصلًا.');
  final inner = widget is HomeSection ? widget.child : widget!;
  return inner.runtimeType;
}

/// عقدة كما تخرج من `DesignNode.toMap()` في اللوحة.
Map<String, Object?> _node(
  String id,
  String type, {
  String? dataSource,
  bool visible = true,
}) => <String, Object?>{
  'id': id,
  'type': type,
  'visible': visible,
  'properties': <String, Object?>{'dataSource': ?dataSource},
  'children': <Object?>[],
};

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
