import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/categories_document_sections.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';
import 'support/fake_design_repository.dart';
import 'support/mock_product_repository.dart';

/// صفحة التصنيفات من مستند التصميم: محتوى الموظف يُرسم فوق المتصفّح،
/// والمتصفّح التفاعلي نفسه لا يزول من الشاشة.
///
/// هذه الصفحة هي ثاني صفحة يطبّق عليها محرّر الأدمن تعديلاته على تطبيق
/// العميل بعد الرئيسية؛ الاختبار يثبت أن مستندًا يحمل صفحة تصنيفات يصل
/// فعلًا إلى الشاشة، وأن غياب المستند يرسم الشاشة كما كانت.
PublishedDesign _designWithCategories(List<Map<String, Object>> children) {
  return PublishedDesign(
    schemaVersion: PublishedDesign.readableSchemaVersion,
    homeSections: const <PublishedSection>[],
    categoriesSections: <PublishedSection>[
      for (final child in children)
        PublishedSection(
          id: child['id']! as String,
          type: child['type']! as String,
          properties: <String, dynamic>{
            ...((child['properties'] ?? const {}) as Map),
          },
        ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required PublishedDesign? design,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final catalog = MockProductRepository();
  final categories = CategoriesCubit(repository: catalog);
  addTearDown(categories.close);
  final designCubit = DesignCubit(
    repository: FakeDesignRepository(design),
  );
  addTearDown(designCubit.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<CategoriesCubit>.value(value: categories),
        BlocProvider<DesignCubit>.value(value: designCubit),
      ],
      child: const MaterialApp(home: CategoriesPage()),
    ),
  );
  categories.ensureLoaded();
  await tester.pump();
  await designCubit.load();
  await tester.pump();
}

void main() {
  testWidgets(
    'a published categories page renders its content above the browser',
    (tester) async {
      await _pump(
        tester,
        design: _designWithCategories(const [
          {
            'id': 'cat_heading_1',
            'type': 'section.heading',
            'properties': {'title': 'اختر ما يعجبك'},
          },
        ]),
      );

      // المحتوى المنشور ظاهر.
      expect(find.text('اختر ما يعجبك'), findsOneWidget);
      // والمتصفّح التفاعلي باقٍ: تبويبات التصنيفات لا تزول من الشاشة.
      expect(find.byType(CategoryTabs), findsOneWidget);
    },
  );

  testWidgets(
    'no categories page in the document keeps the screen as it was',
    (tester) async {
      await _pump(tester, design: PublishedDesign.none);

      // لا محتوى من المستند، والشاشة ترسم متصفّحها وحده.
      expect(find.text('اختر ما يعجبك'), findsNothing);
      expect(find.byType(CategoryTabs), findsOneWidget);
    },
  );

  test('a document without a browser node still counts one', () {
    const document = <PublishedSection>[
      PublishedSection(id: 't1', type: 'section.text'),
    ];
    // المتصفّح عنصر الشاشة الثابت: غيابه من المستند لا يعني حذفه من الشاشة.
    expect(categoriesDocumentHasBrowser(document), isFalse);
    expect(categoriesDocumentHasBrowser(const [
      PublishedSection(
        id: 'b1',
        type: 'section.category_list',
        visible: false,
      ),
    ]), isFalse);
    expect(categoriesDocumentHasBrowser(const [
      PublishedSection(id: 'b2', type: 'section.category_list'),
    ]), isTrue);
  });

  test('PublishedDesign reads and rewrites both pages', () {
    const document = <String, dynamic>{
      'schema_version': 2,
      'pages': [
        {
          'page': 'home',
          'root': {
            'type': 'page.home',
            'children': [
              {
                'id': 'h1',
                'type': 'section.text',
                'visible': true,
                'properties': {'text': 'أهلاً'},
              },
            ],
          },
        },
        {
          'page': 'categories',
          'root': {
            'type': 'page.home',
            'children': [
              {
                'id': 'c1',
                'type': 'section.heading',
                'visible': true,
                'properties': {'title': 'التصنيفات'},
              },
            ],
          },
        },
      ],
    };

    final design = PublishedDesign.fromJson(document)!;
    expect(design.homeSections, hasLength(1));
    expect(design.categoriesSections, hasLength(1));
    expect(design.categoriesSections.first.properties['title'], 'التصنيفات');

    // الرجعة إلى JSON تحمل الصفحتين كما كانا.
    final rewritten = design.toDocument();
    final pages = rewritten['pages'] as List;
    expect(pages, hasLength(2));
    expect((pages.last as Map)['page'], 'categories');
  });
}
