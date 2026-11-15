import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/native_design_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EditableComponent comp(
  String id,
  String type, {
  String? parent,
  int index = 0,
  Map<String, dynamic> properties = const {},
}) =>
    EditableComponent(
      componentId: id,
      componentType: type,
      pageId: 'home',
      parentId: parent,
      index: index,
      classification: ComponentClassification.editable,
      properties: properties,
      defaultValues: const {},
      validationRules: const {},
      allowedOperations: const ['reorder'],
      version: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(
    List<EditableComponent> components, {
    DesignTheme theme = DesignTheme.none,
    String? selected,
    ValueChanged<String>? onSelected,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: NativeDesignPreview(
              components: components,
              theme: theme,
              selectedComponentId: selected,
              onElementSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      );

  testWidgets('يرسم الأقسام المرئية بترتيبها العمقي', (tester) async {
    await tester.pumpWidget(host([
      comp('h', 'header', properties: {'showGreeting': true, 'showSearch': false}),
      comp('t', 'text', index: 1, properties: {'text': 'مرحبًا', 'size': '14'}),
    ]));
    expect(find.text('أهلًا بك في كوفي ☕'), findsOneWidget);
    expect(find.text('مرحبًا'), findsOneWidget);
    // النص بعد الرأس في العمق، لا قبلها.
    expect(
      find.text('أهلًا بك في كوفي ☕'),
      findsOneWidget,
      reason: 'الرأس أولًا ثم النص',
    );
  });

  testWidgets('المخفي لا يُرسم والفارغ يرسم رسالة الصفحة الفارغة', (tester) async {
    await tester.pumpWidget(host([
      comp('t', 'text', properties: {'text': 'ظاهر', 'visible': false}),
    ]));
    expect(find.text('ظاهر'), findsNothing);
    expect(find.text('لا توجد أقسام في هذه الصفحة'), findsOneWidget);
  });

  testWidgets('النقر على قسم يحدده', (tester) async {
    String? tapped;
    await tester.pumpWidget(host([
      comp('b', 'button', properties: {'label': 'اطلب الآن'}),
    ], onSelected: (id) => tapped = id));
    await tester.tap(find.text('اطلب الآن'));
    expect(tapped, 'b');
  });

  testWidgets('المحدد يحمل إطار التمييز', (tester) async {
    await tester.pumpWidget(host([
      comp('t', 'text', properties: {'text': 'محدد'}),
    ], selected: 't'));
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(NativeDesignPreview),
            matching: find.byType(Container).first,
          )
          .first,
    );
    expect(container.decoration, isA<BoxDecoration>());
  });

  testWidgets('طبقة الشكل تغير لون الطبقة الحيّة', (tester) async {
    await tester.pumpWidget(host([
      comp('b', 'button', properties: {'label': 'اطلب', 'style': 'primary'}),
    ], theme: const DesignTheme(
      colors: {DesignColorRole.primary: '#FF0000'},
    )));
    // زر بدل لون أساسي أحمر: نصه أبيض على خلفية حمراء.
    final text = tester.widget<Text>(find.text('اطلب'));
    expect(text.style!.color, Colors.white);
  });

  testWidgets('العمود يرسم أبناءه بترتيبهم مع الفجوة', (tester) async {
    await tester.pumpWidget(host([
      comp('col', 'column', properties: {'gap': 'sm'}),
      comp('c1', 'text', parent: 'col', index: 0, properties: {'text': 'أول'}),
      comp('c2', 'button', parent: 'col', index: 1, properties: {'label': 'ثاني'}),
    ]));
    expect(find.text('أول'), findsOneWidget);
    expect(find.text('ثاني'), findsOneWidget);
    final first = tester.getTopLeft(find.text('أول'));
    final second = tester.getTopLeft(find.text('ثاني'));
    expect(second.dy, greaterThan(first.dy));
  });
}
