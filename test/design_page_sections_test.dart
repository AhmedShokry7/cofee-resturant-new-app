import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/shared/widgets/design_page_sections.dart';
import 'support/fake_design_repository.dart';

/// أقسام أي صفحة من المستند تظهر فوق جسم الصفحة الحقيقي، وغيابها يترك
/// الشاشة كما هي — نفس قاعدة الرئيسية والتصنيفات، مطبّقة على كل صفحة.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required PublishedDesign? design,
  }) async {
    final cubit = DesignCubit(repository: FakeDesignRepository(design));
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider<DesignCubit>.value(
        value: cubit,
        child: const MaterialApp(
          home: Scaffold(
            body: DesignPageSectionsAbove(
              pageId: 'auth',
              child: Text('المحتوى الأصلي'),
            ),
          ),
        ),
      ),
    );
    await cubit.load();
    await tester.pump();
  }

  testWidgets('published auth sections render above the original body', (
    tester,
  ) async {
    await pump(
      tester,
      design: const PublishedDesign(
        schemaVersion: 2,
        extraSections: {
          'auth': [
            PublishedSection(
              id: 'auth_heading',
              type: 'section.heading',
              properties: {'title': 'مرحبًا بك'},
            ),
          ],
        },
      ),
    );

    expect(find.text('مرحبًا بك'), findsOneWidget);
    expect(find.text('المحتوى الأصلي'), findsOneWidget);
  });

  testWidgets('no document keeps the original page untouched', (tester) async {
    await pump(tester, design: PublishedDesign.none);

    expect(find.text('مرحبًا بك'), findsNothing);
    expect(find.text('المحتوى الأصلي'), findsOneWidget);
  });

  test('extra pages round-trip through toDocument and fromJson', () {
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
          'page': 'splash',
          'root': {
            'type': 'page.home',
            'children': [
              {
                'id': 's1',
                'type': 'section.image',
                'visible': true,
                'properties': {'imageUrl': 'https://example.com/logo.png'},
              },
            ],
          },
        },
      ],
    };

    final design = PublishedDesign.fromJson(document)!;
    expect(design.sectionsFor('splash'), hasLength(1));
    expect(design.hasSectionsFor('splash'), isTrue);
    expect(design.hasSectionsFor('welcome'), isFalse);

    final rewritten = design.toDocument();
    final pages = rewritten['pages'] as List;
    expect(pages.map((e) => (e as Map)['page']), ['home', 'splash']);
  });
}
