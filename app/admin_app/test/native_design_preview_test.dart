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
}) => EditableComponent(
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
  }) => MaterialApp(
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
    await tester.pumpWidget(
      host([
        comp(
          'h',
          'header',
          properties: {'showGreeting': true, 'showSearch': false},
        ),
        comp(
          't',
          'text',
          index: 1,
          properties: {'text': 'مرحبًا', 'size': '14'},
        ),
      ]),
    );
    expect(find.text('أهلًا بك في كوفي ☕'), findsOneWidget);
    expect(find.text('مرحبًا'), findsOneWidget);
    // النص بعد الرأس في العمق، لا قبلها.
    expect(
      find.text('أهلًا بك في كوفي ☕'),
      findsOneWidget,
      reason: 'الرأس أولًا ثم النص',
    );
  });

  testWidgets('المخفي لا يُرسم والفارغ يرسم رسالة الصفحة الفارغة', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        comp('t', 'text', properties: {'text': 'ظاهر', 'visible': false}),
      ]),
    );
    expect(find.text('ظاهر'), findsNothing);
    expect(find.text('لا توجد أقسام في هذه الصفحة'), findsOneWidget);
  });

  testWidgets('النقر على قسم يحدده', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      host([
        comp('b', 'button', properties: {'label': 'اطلب الآن'}),
      ], onSelected: (id) => tapped = id),
    );
    await tester.tap(find.text('اطلب الآن'));
    expect(tapped, 'b');
  });

  testWidgets('المحدد يحمل إطار التمييز', (tester) async {
    await tester.pumpWidget(
      host([
        comp('t', 'text', properties: {'text': 'محدد'}),
      ], selected: 't'),
    );
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
    await tester.pumpWidget(
      host(
        [
          comp(
            'b',
            'button',
            properties: {'label': 'اطلب', 'style': 'primary'},
          ),
        ],
        theme: const DesignTheme(colors: {DesignColorRole.primary: '#FF0000'}),
      ),
    );
    // زر بدل لون أساسي أحمر: نصه أبيض على خلفية حمراء.
    final text = tester.widget<Text>(find.text('اطلب'));
    expect(text.style!.color, Colors.white);
  });

  testWidgets('العمود يرسم أبناءه بترتيبهم مع الفجوة', (tester) async {
    await tester.pumpWidget(
      host([
        comp('col', 'column', properties: {'gap': 'sm'}),
        comp(
          'c1',
          'text',
          parent: 'col',
          index: 0,
          properties: {'text': 'أول'},
        ),
        comp(
          'c2',
          'button',
          parent: 'col',
          index: 1,
          properties: {'label': 'ثاني'},
        ),
      ]),
    );
    expect(find.text('أول'), findsOneWidget);
    expect(find.text('ثاني'), findsOneWidget);
    final first = tester.getTopLeft(find.text('أول'));
    final second = tester.getTopLeft(find.text('ثاني'));
    expect(second.dy, greaterThan(first.dy));
  });

  group('الشاشات المدمجة', () {
    testWidgets('إعدادات الافتتاحية تعرض الصورة والنص والمدة', (tester) async {
      await tester.pumpWidget(
        host([
          comp(
            'splash',
            'splashSettings',
            properties: {
              'imageUrl': 'https://example.invalid/splash.png',
              'text_ar': 'مرحباً',
              'textSize': 21,
              'textColor': '#123456',
              'backgroundColor': '#ABCDEF',
              'durationMs': 2400,
              'animation': 'fade',
            },
          ),
        ]),
      );
      expect(find.text('مرحباً'), findsOneWidget);
      expect(find.textContaining('2400ms'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, isNull);
      expect(image.fit, BoxFit.contain);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.color == const Color(0xFFABCDEF),
        ),
        findsOneWidget,
      );
    });

    testWidgets('عنوان الترحيب المنشور يظهر بجزئيه', (tester) async {
      await tester.pumpWidget(
        host([
          comp(
            'wt',
            'welcomeTitle',
            properties: {'highlight': 'قهوتك', 'rest': 'على كيفك', 'size': 30},
          ),
        ]),
      );
      expect(find.textContaining('قهوتك'), findsOneWidget);
      expect(find.textContaining('على كيفك'), findsOneWidget);
    });

    testWidgets('وصف الترحيب المنشور ورابط الصورة يظهران', (tester) async {
      await tester.pumpWidget(
        host([
          comp(
            'wb',
            'welcomeBody',
            properties: {'text': 'جاهز تبدأ؟', 'size': 18},
          ),
          comp(
            'wh',
            'welcomeHero',
            index: 1,
            properties: {
              'imageUrl': 'https://example.invalid/hero.jpg',
              'fit': 'contain',
            },
          ),
        ]),
      );
      expect(find.text('جاهز تبدأ؟'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('الصورة المستقلة تحترم القياس والاحتواء والمحاذاة', (
      tester,
    ) async {
      await tester.pumpWidget(
        host([
          comp(
            'image',
            'image',
            properties: {
              'imageUrl': 'https://example.invalid/editor.png',
              'width': 96,
              'height': 72,
              'fit': 'contain',
              'alignment': 'end',
            },
          ),
        ]),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 96);
      expect(image.height, 72);
      expect(image.fit, BoxFit.contain);
      expect(image.alignment, AlignmentDirectional.centerEnd);
      expect(
        find.ancestor(
          of: find.byType(Image),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Align &&
                widget.alignment == AlignmentDirectional.centerEnd,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('شريحة التعريف ترسم عنوانها ووصفها', (tester) async {
      await tester.pumpWidget(
        host([
          comp(
            's',
            'onboardingSlide',
            properties: {'title': 'اطلب بسهولة', 'body': 'كل شيء من الهاتف'},
          ),
        ]),
      );
      expect(find.text('اطلب بسهولة'), findsOneWidget);
      expect(find.text('كل شيء من الهاتف'), findsOneWidget);
    });

    testWidgets('وقت الانتقال يُعلن مدة الحركة والتقديم التلقائي', (
      tester,
    ) async {
      await tester.pumpWidget(
        host([
          comp(
            'tr',
            'onboardingTransition',
            properties: {'durationMs': '400', 'seconds': '4'},
          ),
        ]),
      );
      expect(find.textContaining('400ms'), findsOneWidget);
      expect(find.textContaining('تلقائي كل 4ث'), findsOneWidget);
    });

    testWidgets('عنوان الدخول المنشور يظهر وأزراره الاجتماعية', (tester) async {
      await tester.pumpWidget(
        host([
          comp('at', 'authTitle', properties: {'text': 'أهلًا بعودتك'}),
          comp('as', 'authSocial', index: 1),
        ]),
      );
      expect(find.text('أهلًا بعودتك'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
    });
  });
}
