import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/native_design_preview.dart';
import 'package:material_ui/material_ui.dart';
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
    PreviewLanguage? previewLanguage,
    PreviewThemeMode? previewThemeMode,
  }) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 390,
        child: NativeDesignPreview(
          components: components,
          theme: theme,
          screenSize: const Size(390, 844),
          selectedComponentId: selected,
          previewLanguage: previewLanguage,
          previewThemeMode: previewThemeMode,
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
    final previewText = tester.widget<Text>(find.text('مرحبًا'));
    expect(previewText.textDirection, isNull);
    expect(previewText.style!.letterSpacing, isNull);
    expect(previewText.overflow, TextOverflow.ellipsis);
    // النص بعد الرأس في العمق، لا قبلها.
    expect(
      find.text('أهلًا بك في كوفي ☕'),
      findsOneWidget,
      reason: 'الرأس أولًا ثم النص',
    );
  });

  testWidgets('البانرات المنشورة تظهر تلقائيًا بلا قائمة مسودة', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NativeDesignPreview(
            components: [comp('published-banner', 'bannerCarousel')],
            theme: DesignTheme.none,
            publishedBannerImages: const [
              'https://example.invalid/published.png',
            ],
            onElementSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(
      (tester.widget<Image>(find.byType(Image).first).image as NetworkImage)
          .url,
      'https://example.invalid/published.png',
    );
  });

  testWidgets('صورة بانر المسودة تظهر وتتغير مباشرة في المعاينة الأصلية', (
    tester,
  ) async {
    Widget preview(String imageUrl, {int count = 1}) => host([
      comp(
        'banner-draft',
        'bannerCarousel',
        properties: {
          'height': 180,
          'bannerDraftCount': count,
          'bannerDraft_0_image': imageUrl,
        },
      ),
    ]);

    await tester.pumpWidget(preview('https://example.invalid/first.png'));
    expect(find.byType(PageView), findsOneWidget);
    expect(
      (tester.widget<Image>(find.byType(Image).first).image as NetworkImage)
          .url,
      'https://example.invalid/first.png',
    );

    await tester.pumpWidget(preview('https://example.invalid/second.png'));
    expect(
      (tester.widget<Image>(find.byType(Image).first).image as NetworkImage)
          .url,
      'https://example.invalid/second.png',
    );

    await tester.pumpWidget(preview('', count: 0));
    expect(find.byType(PageView), findsNothing);
    expect(find.text('عرض اليوم'), findsNothing);
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

  testWidgets('معاينة النص تطبق الاتجاه والتباعد والقصّ المحددة', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        comp(
          'styled',
          'text',
          properties: {
            'text': 'formatted text',
            'textDirection': 'rtl',
            'letterSpacing': 2.5,
            'overflow': 'fade',
          },
        ),
      ]),
    );

    final text = tester.widget<Text>(find.text('formatted text'));
    expect(text.textDirection, TextDirection.rtl);
    expect(text.style!.letterSpacing, 2.5);
    expect(text.overflow, TextOverflow.fade);
  });

  testWidgets('هوامش الموضع تغيّر موضع العنصر داخل المعاينة', (tester) async {
    await tester.pumpWidget(
      host([
        comp(
          'positioned',
          'text',
          properties: {'text': 'عنصر بموضع', 'marginTop': 24, 'marginLeft': 16},
        ),
      ]),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.only(top: 24, left: 16),
      ),
      findsOneWidget,
      reason: 'هوامش الموضع يجب أن تصل إلى طبقة الشكل في المعاينة',
    );
  });

  testWidgets('المعاينة تختار نص العنوان بحسب لغة واجهة التطبيق', (
    tester,
  ) async {
    final previousLanguage = AppLocale.instance.language;
    addTearDown(() => AppLocale.instance.debugSet(previousLanguage));

    AppLocale.instance.debugSet(AppLanguage.english);
    await tester.pumpWidget(
      host([
        comp(
          'heading',
          'heading',
          properties: {
            'title_ar': 'العنوان العربي',
            'title_en': 'English heading',
          },
        ),
        comp(
          'text',
          'text',
          index: 1,
          properties: {'text_ar': 'النص العربي', 'text_en': 'English body'},
        ),
      ]),
    );
    expect(find.text('English heading'), findsOneWidget);
    expect(find.text('English body'), findsOneWidget);
    expect(find.text('العنوان العربي'), findsNothing);

    AppLocale.instance.debugSet(AppLanguage.arabic);
    await tester.pumpWidget(
      host([
        comp(
          'heading',
          'heading',
          properties: {
            'title_ar': 'العنوان العربي',
            'title_en': 'English heading',
          },
        ),
        comp(
          'text',
          'text',
          index: 1,
          properties: {'text_ar': 'النص العربي', 'text_en': 'English body'},
        ),
      ]),
    );
    expect(find.text('العنوان العربي'), findsOneWidget);
    expect(find.text('النص العربي'), findsOneWidget);
    expect(find.text('English heading'), findsNothing);
  });

  testWidgets('عناوين أقسام المتجر تتبع اللغة وتظهر افتراضيًا', (tester) async {
    final previousLanguage = AppLocale.instance.language;
    addTearDown(() => AppLocale.instance.debugSet(previousLanguage));

    AppLocale.instance.debugSet(AppLanguage.english);
    await tester.pumpWidget(
      host([
        comp('categories', 'categoryList'),
        comp('popular', 'productStrip', index: 1),
        comp('bundles', 'bundleList', index: 2),
      ]),
    );
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Bundles'), findsOneWidget);
    expect(find.text('التصنيفات'), findsNothing);

    AppLocale.instance.debugSet(AppLanguage.arabic);
    await tester.pumpWidget(
      host([
        comp('categories', 'categoryList'),
        comp('popular', 'productStrip', index: 1),
        comp('bundles', 'bundleList', index: 2),
      ]),
    );
    expect(find.text('التصنيفات'), findsOneWidget);
    expect(find.text('الأكثر طلبًا'), findsOneWidget);
    expect(find.text('الباقات'), findsOneWidget);
    expect(find.text('Categories'), findsNothing);
  });

  testWidgets('لغة المعاينة تعلو على لغة واجهة الأدمن في نصوص الأقسام', (
    tester,
  ) async {
    final previousLanguage = AppLocale.instance.language;
    addTearDown(() => AppLocale.instance.debugSet(previousLanguage));
    AppLocale.instance.debugSet(AppLanguage.english);

    await tester.pumpWidget(
      host([
        comp(
          'cta',
          'welcomeCta',
          properties: {'label_ar': 'ابدأ الآن', 'label_en': 'Start now'},
        ),
      ], previewLanguage: PreviewLanguage.arabic),
    );

    expect(find.text('ابدأ الآن'), findsOneWidget);
    expect(find.text('Start now'), findsNothing);
  });

  testWidgets('زر الترحيب المخفي لا يُرسم في المعاينة', (tester) async {
    await tester.pumpWidget(
      host([
        comp(
          'cta',
          'welcomeCta',
          properties: {
            'label_ar': 'مخفي',
            'label_en': 'Hidden',
            'visible': false,
          },
        ),
      ]),
    );
    expect(find.text('مخفي'), findsNothing);
    expect(find.text('Hidden'), findsNothing);
  });

  testWidgets('الوضع الداكن للمعاينة يغيّر خلفيتها', (tester) async {
    await tester.pumpWidget(
      host([
        comp('t', 'text', properties: {'text': 'نص'}),
      ], previewThemeMode: PreviewThemeMode.dark),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == AppColor.darkBackground,
      ),
      findsOneWidget,
    );
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
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<NetworkImage>(),
        reason: 'يجب أن تعرض معاينة الافتتاحية الصورة المختارة فعلًا',
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, closeTo(257.4, 0.1));
      expect(image.height, isNull);
      expect(image.fit, BoxFit.contain);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.color == const Color(0xFFABCDEF),
        ),
        findsOneWidget,
      );
      ComponentRegistry.initialize();
      final document = DesignDocumentCodec.document({
        'splash': [
          comp(
            'splash-settings',
            'splashSettings',
            properties: const {
              'imageUrl': 'https://example.invalid/splash.png',
              'backgroundColor': '#ABCDEF',
              'durationMs': 2400,
            },
          ),
        ],
      });
      final splashNode =
          ((document['pages'] as List).single as Map)['root'] as Map;
      final section = ((splashNode['children'] as List).single as Map);
      expect(section['type'], DesignContract.splashSettings);
      expect(
        (section['properties'] as Map)['imageUrl'],
        'https://example.invalid/splash.png',
      );
      expect((section['properties'] as Map)['backgroundColor'], '#ABCDEF');
    });

    testWidgets('تغيير صورة ولون الافتتاحية يُحدّث المعاينة مباشرة', (
      tester,
    ) async {
      Widget splashWith(String url, String color) => host([
        comp(
          'splash-live',
          'splashSettings',
          properties: {'imageUrl': url, 'backgroundColor': color},
        ),
      ]);

      await tester.pumpWidget(
        splashWith('https://example.invalid/first.png', '#112233'),
      );
      expect(
        (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url,
        'https://example.invalid/first.png',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.color == const Color(0xFF112233),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        splashWith('https://example.invalid/second.png', '#445566'),
      );
      expect(
        (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url,
        'https://example.invalid/second.png',
        reason: 'اختيار صورة جديدة يجب أن يستبدل الصورة في المعاينة',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.color == const Color(0xFF445566),
        ),
        findsOneWidget,
        reason: 'تغيير لون الخلفية يجب أن يُعاد رسمه في المعاينة',
      );
    });

    testWidgets('قياس صورة الافتتاحية وطريقة عرضها تنعكس على الصورة', (
      tester,
    ) async {
      await tester.pumpWidget(
        host([
          comp(
            'splash-sized',
            'splashSettings',
            properties: {
              'imageUrl': 'https://example.invalid/sized.png',
              'imageWidth': 210,
              'imageHeight': 160,
              'imageFit': 'cover',
            },
          ),
        ]),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 210);
      expect(image.height, 160);
      expect(image.fit, BoxFit.cover);
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
