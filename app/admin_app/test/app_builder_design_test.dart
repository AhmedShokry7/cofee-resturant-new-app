import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/registry/action_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/data_source_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_spec.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_tree.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_validator.dart';

/// صفحة تجريبية بجذر واحد وأبناء مسجّلين مسموحين.
DesignDocument _document(List<DesignNode> sections) => DesignDocument(
  schemaVersion: WidgetRegistry.schemaVersion,
  pages: <AppPage, DesignNode>{
    AppPage.home: WidgetRegistry.node(
      WidgetTypes.pageHome,
      'home',
      children: sections,
    ),
    AppPage.categories: WidgetRegistry.node(
      WidgetTypes.pageCategories,
      'categories',
      children: <DesignNode>[
        WidgetRegistry.node(WidgetTypes.categoryList, 'categories_tabs'),
        WidgetRegistry.node(WidgetTypes.productGrid, 'categories_products'),
      ],
    ),
    AppPage.search: WidgetRegistry.node(
      WidgetTypes.pageSearch,
      'search',
      children: <DesignNode>[
        WidgetRegistry.node(WidgetTypes.searchBar, 'search_field'),
        WidgetRegistry.node(WidgetTypes.productGrid, 'search_results'),
      ],
    ),
  },
);

/// رئيسية فيها الرأس وحده: أساس التدقيق، ثم يُضاف إليها ما يريد الاختبار.
DesignDocument _homeWith(DesignNode section) => _document(<DesignNode>[
  WidgetRegistry.node(WidgetTypes.header, 'home_header'),
  section,
]);

Map<String, WidgetSpec> get _specsByName => <String, WidgetSpec>{
  for (final spec in WidgetRegistry.specs) spec.type: spec,
};

void main() {
  group('السجل نفسه', () {
    test('كل نوع له تعريف وحيد ومعرّفه مطابق لمفتاحه', () {
      expect(WidgetRegistry.specs, isNotEmpty);
      expect(_specsByName.length, WidgetRegistry.specs.length);
      for (final spec in WidgetRegistry.specs) {
        expect(WidgetRegistry.of(spec.type), same(spec));
      }
    });

    test('أنواع الأبناء والآباء كلها مسجّلة، ولا حلقة بين أب وابنه', () {
      for (final spec in WidgetRegistry.specs) {
        for (final child in spec.childTypes) {
          expect(WidgetRegistry.knows(child), isTrue, reason: spec.type);
        }
        for (final parent in spec.parentTypes) {
          expect(WidgetRegistry.knows(parent), isTrue, reason: spec.type);
          final parentSpec = WidgetRegistry.of(parent)!;
          expect(
            parentSpec.canHaveChildren,
            isTrue,
            reason: '${spec.type} يدّعي أنه ابن لـ $parent وهو ليس حاوية',
          );
          // العلاقة متبادلة: أب يذكر ابنًا وابنه لا يذكره لا يُفلت أبدًا.
          expect(
            parentSpec.allowsChild(spec.type),
            isTrue,
            reason:
                '$parent يذكر ${spec.type} بين أبنائه ولا يذكره هو بين آباءه',
          );
        }
      }
    });

    test('حاوية تقبل أبناءً لها قائمة أبناء، وورقة لا تذكر أبناء', () {
      for (final spec in WidgetRegistry.specs) {
        if (spec.canHaveChildren) {
          expect(spec.childTypes, isNotEmpty, reason: spec.type);
        } else {
          expect(spec.childTypes, isEmpty, reason: spec.type);
        }
      }
    });

    test('مفاتيح الإجراءات والمصادر مسجّلة، وخصائص النوع نفسه مقفلة عليها', () {
      for (final spec in WidgetRegistry.specs) {
        for (final key in spec.actionKeys) {
          expect(
            ActionRegistry.knows(key),
            isTrue,
            reason: '${spec.type}/$key',
          );
        }
        for (final key in spec.dataSourceKeys) {
          expect(
            DataSourceRegistry.knows(key),
            isTrue,
            reason: '${spec.type}/$key',
          );
        }
        final action = spec.property('action');
        if (action != null) {
          for (final choice in action.choices) {
            expect(
              spec.actionKeys.contains(choice),
              isTrue,
              reason: '${spec.type}: إجراء $choice ليس في قائمة المكوّن',
            );
          }
        }
        final source = spec.property('dataSource');
        if (source != null) {
          for (final choice in source.choices) {
            expect(
              spec.dataSourceKeys.contains(choice),
              isTrue,
              reason: '${spec.type}: مصدر $choice ليس في قائمة المكوّن',
            );
          }
        }
      }
    });

    test('لا مفتاح خاصية مكرر في المكوّن نفسه، والقيم الافتراضية صالحة', () {
      for (final spec in WidgetRegistry.specs) {
        final keys = spec.properties.map((p) => p.key).toList();
        expect(keys.toSet().length, keys.length, reason: spec.type);
        for (final property in spec.properties) {
          final reason = property.reject(property.defaultValue);
          // القيمة الافتراضية غير اختيارية لا بدّ أن تمرّ فاحصتها نفسها.
          if (property.defaultValue != null || !property.optional) {
            expect(reason, isNull, reason: '${spec.type}/${property.key}');
          }
        }
      }
    });

    test('الرأس مقفول وأساس، ولا يقبله غير جذر الرئيسية', () {
      final header = WidgetRegistry.of(WidgetTypes.header)!;
      expect(header.level, WidgetEditLevel.locked);
      expect(header.mandatory, isTrue);
      expect(header.parentTypes, <String>[WidgetTypes.pageHome]);
    });
  });

  group('المستند الافتراضي', () {
    test('هو ترتيب العميل الحالي، ويُقبل النشر كما هو', () {
      final document = WidgetRegistry.defaultDocument();
      expect(
        document.sectionsOf(AppPage.home).map((node) => node.type).toList(),
        <String>[
          WidgetTypes.header,
          WidgetTypes.searchBar,
          WidgetTypes.bannerCarousel,
          WidgetTypes.categoryList,
          WidgetTypes.productStrip,
          WidgetTypes.promoBanner,
          WidgetTypes.productStrip,
          WidgetTypes.bundleList,
        ],
      );
      final validation = DesignValidator.validate(document);
      expect(validation.issues, isEmpty, reason: '${validation.issues}');
      expect(validation.isPublishable, isTrue);
    });

    test('يرجع إلى JSON ومنه إلى نفس الشجرة والقيم', () {
      final document = WidgetRegistry.defaultDocument();
      final restored = DesignDocument.fromMap(document.toMap());
      expect(restored.schemaVersion, document.schemaVersion);
      expect(restored.pages.keys, document.pages.keys);
      for (final page in AppPage.values) {
        expect(
          restored.rootOf(page)?.toMap(),
          document.rootOf(page)?.toMap(),
          reason: page.key,
        );
      }
    });

    test('القراءة ترمي على نوع مجهول بدل أن تصمت نصف تصميم', () {
      final document = WidgetRegistry.defaultDocument();
      final broken = <Object?, Object?>{
        ...document.toMap(),
        'pages': <Object?>[
          <String, Object?>{
            'page': 'home',
            'root': <String, Object?>{
              'id': 'home',
              'type': 'page.home',
              'children': <Object?>[
                <String, Object?>{'id': 'x', 'type': 'section.not_registered'},
              ],
            },
          },
        ],
      };
      // النوع المجهول عقدة لا مستند: تقرأ، ثم يرفضها التدقيق قبل النشر.
      final restored = DesignDocument.fromMap(broken);
      final validation = DesignValidator.validate(restored);
      expect(
        validation.issues.map((issue) => issue.code),
        contains(DesignIssueCode.unknownType),
      );
    });
  });

  group('التدقيق يمسك الكسر قبل النشر', () {
    test('بلا رأس: صفحة تنشر بلا تحية مرفوضة', () {
      final document = _document(<DesignNode>[]);
      expect(
        DesignValidator.validate(document).issues.map((i) => i.code),
        containsAll(<DesignIssueCode>[
          DesignIssueCode.emptyPage,
          DesignIssueCode.mandatoryMissing,
        ]),
      );
    });

    test('معرّف مكرر، وتكرار العقدة نفسها في صفحة أخرى', () {
      final document = _document(<DesignNode>[
        WidgetRegistry.node(WidgetTypes.header, 'home_header'),
        WidgetRegistry.node(WidgetTypes.bannerCarousel, 'home_header'),
      ]);
      expect(
        DesignValidator.validate(document).issues.map((i) => i.code),
        contains(DesignIssueCode.duplicateId),
      );
    });

    test('الرأس مخفّى: الأساس لا يُخفى ولو بقي في الشجرة', () {
      final header = WidgetRegistry.node(
        WidgetTypes.header,
        'home_header',
      ).copyWith(isVisible: false);
      final document = _document(<DesignNode>[header]);
      expect(
        DesignValidator.validate(document).issues.map((i) => i.code),
        contains(DesignIssueCode.mandatoryHidden),
      );
    });

    test('ابن لا يقبله أبوه، وحاوية فارغة لا تُنشر', () {
      final document = DesignDocument(
        schemaVersion: WidgetRegistry.schemaVersion,
        pages: <AppPage, DesignNode>{
          AppPage.home: WidgetRegistry.node(
            WidgetTypes.pageHome,
            'home',
            children: <DesignNode>[
              WidgetRegistry.node(WidgetTypes.header, 'home_header'),
              WidgetRegistry.node(
                WidgetTypes.bannerCarousel,
                'banners',
                children: <DesignNode>[
                  WidgetRegistry.node(
                    WidgetTypes.productGrid,
                    'inside_carousel',
                  ),
                ],
              ),
              WidgetRegistry.node(WidgetTypes.column, 'empty_column'),
            ],
          ),
        },
      );
      final issues = DesignValidator.validate(document).ofPage(AppPage.home);
      expect(
        issues.map((i) => i.code),
        contains(DesignIssueCode.illegalNesting),
      );
      expect(
        issues.map((i) => i.code),
        contains(DesignIssueCode.emptyContainer),
      );
    });

    test('مصدر يطلب تصنيفًا بلا تصنيف', () {
      final document = _homeWith(
        WidgetRegistry.node(
          WidgetTypes.productStrip,
          'strip',
          overrides: const <String, Object?>{
            'dataSource': DataSourceRegistry.categoryProducts,
            'action': ActionRegistry.none,
            'linkLabel': null,
          },
        ),
      );
      expect(
        DesignValidator.validate(document).issues.map((i) => i.code),
        contains(DesignIssueCode.dataSourceParameterMissing),
      );
    });

    test('تسمية رابط بلا إجراء، وإجراء بلا تسمية', () {
      Set<DesignIssueCode> codesFor(Map<String, Object?> overrides) {
        final document = _homeWith(
          WidgetRegistry.node(
            WidgetTypes.productStrip,
            'strip',
            overrides: overrides,
          ),
        );
        return DesignValidator.validate(document).issues
            .map((issue) => issue.code)
            .toSet();
      }

      expect(
        codesFor(const <String, Object?>{
          'linkLabel': 'عرض المزيد',
          'action': ActionRegistry.none,
        }),
        contains(DesignIssueCode.linkLabelWithoutAction),
      );
      expect(
        codesFor(const <String, Object?>{
          'linkLabel': '',
          'action': ActionRegistry.seeAllProducts,
        }),
        contains(DesignIssueCode.actionWithoutLabel),
      );
    });

    test('خاصية لا يعرفها المكوّن وقيمة خارج حدودها', () {
      final document = _homeWith(
        WidgetRegistry.node(
          WidgetTypes.bannerCarousel,
          'banners',
          overrides: const <String, Object?>{
            'maxItems': 99,
            'invented': 'لا مكان له',
          },
        ),
      );
      final codes = DesignValidator.validate(document).issues
          .map((issue) => issue.code)
          .toSet();
      expect(codes, contains(DesignIssueCode.unknownProperty));
      expect(codes, contains(DesignIssueCode.invalidProperty));
    });

    test('مخطط لا يعرفه هذا البناء يُرفض ولو كانت الشجرة سليمة', () {
      final document = WidgetRegistry.defaultDocument();
      final future = DesignDocument(
        schemaVersion: document.schemaVersion + 1,
        pages: document.pages,
      );
      expect(
        DesignValidator.validate(future).issues.map((i) => i.code),
        contains(DesignIssueCode.schemaVersionMismatch),
      );
    });
  });

  group('الشجرة', () {
    test('إضافة من المكتبة في موضع محدد ترجع نسخة ولا تلمس الأصل', () {
      final document = WidgetRegistry.defaultDocument();
      final root = document.rootOf(AppPage.home)!;
      final child = WidgetRegistry.node(WidgetTypes.divider, 'divider');

      final next = DesignTree.insert(root, 'home', 1, child);

      expect(root.children.length, 8);
      expect(next.children[1].id, 'divider');
      expect(DesignTree.find(next, 'divider')?.type, WidgetTypes.divider);
    });

    test('الفحص يسبق الإفلات: لا شيء يُضاف حيث لا يُرسم', () {
      final root = WidgetRegistry.defaultDocument().rootOf(AppPage.home)!;

      expect(
        DesignTree.rejectionOfAttach(
          root: root,
          parentId: 'home',
          childType: WidgetTypes.header,
        ),
        DesignEditRejection.none,
      );
      // العمود لا يذكر الرأس بين أبنائه المسموحين.
      final column = WidgetRegistry.node(WidgetTypes.column, 'column');
      expect(
        DesignTree.rejectionOfAttach(
          root: DesignTree.insert(root, 'home', 1, column),
          parentId: 'column',
          childType: WidgetTypes.header,
        ),
        DesignEditRejection.parentRefusesChild,
      );
      // كبسولة البحث صفحة-level عند العميل: العمود يقبلها اسميًا لكنها لا تسكنه.
      expect(
        DesignTree.rejectionOfAttach(
          root: DesignTree.insert(root, 'home', 1, column),
          parentId: 'column',
          childType: WidgetTypes.searchBar,
        ),
        DesignEditRejection.childRefusesParent,
      );
      expect(
        DesignTree.rejectionOfAttach(
          root: root,
          parentId: 'home_search',
          childType: WidgetTypes.productGrid,
        ),
        DesignEditRejection.parentIsNotContainer,
      );
      expect(
        DesignTree.rejectionOfAttach(
          root: root,
          parentId: 'home',
          childType: 'page.categories',
        ),
        DesignEditRejection.parentRefusesChild,
      );
      expect(
        DesignTree.rejectionOfAttach(
          root: root,
          parentId: 'home',
          childType: 'section.not_registered',
        ),
        DesignEditRejection.unknownType,
      );
    });

    test('النقل يرفض أن تسكن الحاوية في بطن ابنها', () {
      final column = WidgetRegistry.node(
        WidgetTypes.column,
        'column',
        children: <DesignNode>[WidgetRegistry.node(WidgetTypes.text, 'note')],
      );
      final root = DesignTree.insert(
        WidgetRegistry.defaultDocument().rootOf(AppPage.home)!,
        'home',
        1,
        column,
      );

      expect(
        DesignTree.rejectionOfMove(root, 'column', 'column'),
        DesignEditRejection.intoOwnDescendant,
      );
      expect(
        DesignTree.rejectionOfMove(root, 'column', 'note'),
        DesignEditRejection.intoOwnDescendant,
      );
      expect(
        DesignTree.rejectionOfMove(root, 'home_header', 'home'),
        DesignEditRejection.lockedComponent,
      );

      final moved = DesignTree.move(root, 'note', 'home', 0);
      expect(DesignTree.parentOf(moved, 'note')?.id, 'home');
      expect(DesignTree.find(moved, 'column')?.children, isEmpty);
    });

    test('التكرار يعطي معرّفات حرة لكل العقدة وأبنائها', () {
      final column = WidgetRegistry.node(
        WidgetTypes.column,
        'column',
        children: <DesignNode>[WidgetRegistry.node(WidgetTypes.text, 'note')],
      );
      final root = DesignTree.insert(
        WidgetRegistry.defaultDocument().rootOf(AppPage.home)!,
        'home',
        1,
        column,
      );

      final doubled = DesignTree.duplicate(root, 'column');

      final ids = DesignTree.idsOf(doubled);
      expect(ids.length, DesignTree.idsOf(root).length + 2);
      expect(DesignTree.find(doubled, 'column-2'), isNotNull);
      expect(DesignTree.parentOf(doubled, 'column-2')?.id, 'home');
      // مقفول لا يُكرَّر: نسخة من الرأس تعني تحيتين في شاشة واحدة.
      expect(DesignTree.duplicate(root, 'home_header'), same(root));
    });

    test('الحذف يترك الحاوية الممتلئة، والإخفاء يترك المقفول', () {
      final root = WidgetRegistry.defaultDocument().rootOf(AppPage.home)!;

      expect(
        DesignTree.rejectionOfRemove(root, 'home'),
        DesignEditRejection.containerNotEmpty,
      );
      expect(
        DesignTree.rejectionOfRemove(root, 'home_header'),
        DesignEditRejection.lockedComponent,
      );
      expect(
        DesignTree.rejectionOfRemove(root, 'home_banners'),
        DesignEditRejection.none,
      );

      expect(
        DesignTree.setVisible(root, 'home_header', false).isVisible,
        isTrue,
      );
      expect(DesignTree.setVisible(root, 'home_banners', false).id, 'home');
      expect(
        DesignTree.find(
          DesignTree.setVisible(root, 'home_banners', false),
          'home_banners',
        )!.isVisible,
        isFalse,
      );
    });

    test('المعرّف الحرّ يتجاوز كل ما أخذ', () {
      final root = WidgetRegistry.defaultDocument().rootOf(AppPage.home)!;
      expect(
        DesignTree.freshId(DesignTree.idsOf(root), DesignTree.baseOf(WidgetTypes.divider)),
        'divider',
      );
      expect(
        DesignTree.freshId(<String>{
          'divider',
          'divider-2',
        }, DesignTree.baseOf(WidgetTypes.divider)),
        'divider-3',
      );
    });

    test('نسخة عنصر باسمه لا بنوعه', () {
      final root = WidgetRegistry.defaultDocument().rootOf(AppPage.home)!;
      final duplicated = DesignTree.duplicate(root, 'home_banners');
      final clone = duplicated.children[
        duplicated.children.indexWhere((child) => child.id == 'home_banners') +
            1
      ];
      expect(clone.id, 'home_banners-2');
      expect(clone.type, 'section.banner_carousel');
    });

    test('تعديل المستند لا يتعدى على صفحة مقفلة', () {
      final document = WidgetRegistry.defaultDocument();
      final edited = DesignDocumentEdit.setVisible(
        document,
        AppPage.cart,
        id: 'anything',
        isVisible: false,
      );
      expect(edited, same(document));

      final moved = DesignDocumentEdit.newNode(
        document,
        AppPage.categories,
        WidgetTypes.spacer,
      );
      expect(moved.type, WidgetTypes.spacer);
      expect(moved.properties['size'], 'lg');
      final intoCategories = DesignDocumentEdit.insert(
        document,
        AppPage.categories,
        parentId: 'categories',
        index: 0,
        child: moved,
      );
      expect(
        DesignTree.find(intoCategories.rootOf(AppPage.categories)!, moved.id),
        isNotNull,
      );
      expect(DesignValidator.validate(intoCategories).isPublishable, isTrue);
    });
  });
}
