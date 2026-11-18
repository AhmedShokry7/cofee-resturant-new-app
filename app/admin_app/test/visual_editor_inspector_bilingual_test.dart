import 'package:material_ui/material_ui.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/properties_inspector_panel.dart';

/// حقل النص ثنائي اللغة في لوحة الخصائص: حقل واحد يكتب اللغتين معًا،
/// والفصل بين اللغتين استثناء يفتحه الموظف زرًا — لا وجه افتراضي.
void main() {
  ComponentRegistry.initialize();

  final component = EditableComponent(
    componentId: 'onboarding_onboardingSlide_0',
    componentType: 'onboardingSlide',
    pageId: 'onboarding',
    index: 0,
    classification: ComponentClassification.editable,
    properties: {
      'imageUrl': '',
      'title_ar': '',
      'title_en': '',
      'body_ar': '',
      'body_en': '',
      'visible': true,
    },
    defaultValues: const {
      'imageUrl': '',
      'title_ar': '',
      'title_en': '',
      'body_ar': '',
      'body_en': '',
    },
    validationRules: const {},
    allowedOperations: const ['add', 'delete', 'duplicate', 'reorder', 'hide'],
    version: 1,
  );

  Future<void> pumpPanel(
    WidgetTester tester, {
    required ValueChanged<String> onKeyChanged,
    required void Function(String key) onReset,
    EditableComponent? panelComponent,
    Future<String?> Function()? onPickImage,
    Future<String?> Function()? onBrowseImages,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: PropertiesInspectorPanel(
              component: panelComponent ?? component,
              onPropertyChanged: ({
                required componentId,
                required propertyKey,
                required value,
              }) => onKeyChanged('$propertyKey=${value ?? ''}'),
              onResetProperty: ({required componentId, required propertyKey}) =>
                  onReset(propertyKey),
              onPickImage: onPickImage,
              onBrowseImages: onBrowseImages,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('general color properties open the full color picker', (
    tester,
  ) async {
    // حقول الموضع الجديدة تطول اللوحة؛ نرفع سطح الاختبار ليظل زر اللون
    // داخل الشاشة بدل الاعتماد على تمرير لوحة غير قابلة للتمرير في الاختبار.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final text = component.copyWith(
      componentId: 'text',
      componentType: 'text',
      properties: {'text_ar': 'نص', 'text_en': 'Text', 'color': '#123456'},
    );
    await pumpPanel(
      tester,
      onKeyChanged: (_) {},
      onReset: (_) {},
      panelComponent: text,
    );

    await tester.tap(find.byKey(const ValueKey('color-picker-text-color')));
    await tester.pumpAndSettle();
    expect(find.text(S.visualEditorPickColor), findsOneWidget);
    expect(find.byType(ColorPicker), findsOneWidget);
  });

  testWidgets(
    'splash color property opens a palette and emits selected color',
    (tester) async {
      final splash = EditableComponent(
        componentId: 'splash',
        componentType: 'splashSettings',
        pageId: 'splash',
        index: 0,
        classification: ComponentClassification.editable,
        properties: const {
          'imageUrl': '',
          'backgroundColor': '#FFFFFF',
          'visible': true,
        },
        defaultValues: const {'imageUrl': '', 'backgroundColor': '#FFFFFF'},
        validationRules: const {},
        allowedOperations: const ['edit', 'hide'],
        version: 1,
      );
      final changed = <String>[];
      await pumpPanel(
        tester,
        onKeyChanged: changed.add,
        onReset: (_) {},
        panelComponent: splash,
      );

      await tester.tap(find.byKey(const ValueKey('splash-color-picker')).first);
      await tester.pumpAndSettle();
      expect(find.text(S.visualEditorPickColor), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('splash-swatch-#2E7D32')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.visualEditorApplyColor));
      await tester.pumpAndSettle();

      expect(changed, contains('backgroundColor=#2E7D32'));
    },
  );

  testWidgets(
    'splash image size fields show the effective auto values and save edits',
    (tester) async {
      final splash = EditableComponent(
        componentId: 'splash',
        componentType: 'splashSettings',
        pageId: 'splash',
        index: 0,
        classification: ComponentClassification.editable,
        properties: const {
          'imageUrl': '',
          'backgroundColor': '#FFFFFF',
          'visible': true,
        },
        defaultValues: const {'imageUrl': '', 'backgroundColor': '#FFFFFF'},
        validationRules: const {},
        allowedOperations: const ['edit', 'hide'],
        version: 1,
      );
      final changed = <String>[];
      await pumpPanel(
        tester,
        onKeyChanged: changed.add,
        onReset: (_) {},
        panelComponent: splash,
      );

      final numericValues = tester
          .widgetList<TextField>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.keyboardType ==
                      const TextInputType.numberWithOptions(decimal: true),
            ),
          )
          .map((field) => field.controller?.text)
          .toList();
      // في سطح الاختبار 800×600: العرض التلقائي 320 ثم الارتفاع بنسبة
      // شعار الافتتاحية 827/1024 ≈ 258.
      expect(numericValues, contains('320'));
      expect(numericValues, contains('258'));

      final widthField = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == '320',
      );
      await tester.enterText(widthField, '400');
      await tester.pump();
      expect(changed, contains('imageWidth=400.0'));
    },
  );

  testWidgets('Arabic and English fields show both source texts by default', (
    tester,
  ) async {
    final bilingual = component.copyWith(
      properties: {
        ...component.properties,
        'title_ar': 'عنوان عربي موجود',
        'title_en': 'Existing English title',
      },
    );
    await pumpPanel(
      tester,
      onKeyChanged: (_) {},
      onReset: (_) {},
      panelComponent: bilingual,
    );

    expect(find.text(S.visualEditorBilingualArabicLabel), findsNWidgets(2));
    expect(find.text(S.visualEditorBilingualEnglishLabel), findsNWidgets(2));
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((field) => field.controller?.text == 'عنوان عربي موجود'),
      isTrue,
    );
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((field) => field.controller?.text == 'Existing English title'),
      isTrue,
    );
  });

  testWidgets('the merged field prefers the current interface language', (
    tester,
  ) async {
    final previousLanguage = AppLocale.instance.language;
    addTearDown(() => AppLocale.instance.debugSet(previousLanguage));
    AppLocale.instance.debugSet(AppLanguage.english);
    final bilingual = component.copyWith(
      properties: {
        ...component.properties,
        'title_ar': 'عنوان عربي',
        'title_en': 'English title',
      },
    );

    await pumpPanel(
      tester,
      onKeyChanged: (_) {},
      onReset: (_) {},
      panelComponent: bilingual,
    );

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      fields.any((field) => field.controller?.text == 'عنوان عربي'),
      isTrue,
    );
    expect(
      fields.any((field) => field.controller?.text == 'English title'),
      isTrue,
    );
  });

  testWidgets('numeric input follows external property reset/update', (
    tester,
  ) async {
    ComponentRegistry.register(
      ComponentRegistryEntry(
        componentType: 'testNumeric',
        displayName: 'Numeric test',
        description: '',
        category: 'test',
        classification: ComponentClassification.editable,
        properties: {
          'value': ComponentPropertyDefinition(
            key: 'value',
            label: 'Value',
            description: '',
            type: PropertyType.number,
            defaultValue: 2,
          ),
        },
        allowedParentTypes: const [],
        allowedChildTypes: const [],
        allowedOperations: const ['edit'],
        defaultValues: const {'value': 2},
        validationRules: const {},
        iconName: 'numbers',
        version: 1,
      ),
    );
    final numeric = component.copyWith(
      componentId: 'numeric',
      componentType: 'testNumeric',
      pageId: 'home',
      properties: {'value': 2},
      defaultValues: const {'value': 2},
    );
    final numberField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.keyboardType ==
              const TextInputType.numberWithOptions(decimal: true),
    );

    await pumpPanel(
      tester,
      onKeyChanged: (_) {},
      onReset: (_) {},
      panelComponent: numeric,
    );
    expect(tester.widget<TextField>(numberField).controller!.text, '2');

    await pumpPanel(
      tester,
      onKeyChanged: (_) {},
      onReset: (_) {},
      panelComponent: numeric.copyWith(properties: {'value': 4}),
    );
    expect(tester.widget<TextField>(numberField).controller!.text, '4');

    await pumpPanel(
      tester,
      onKeyChanged: (_) {},
      onReset: (_) {},
      panelComponent: numeric.copyWith(properties: {'value': null}),
    );
    expect(tester.widget<TextField>(numberField).controller!.text, '2');
  });

  testWidgets('typing in the merged field writes both languages', (
    tester,
  ) async {
    final changed = <String>[];
    await pumpPanel(tester, onKeyChanged: changed.add, onReset: (_) {});

    // حقل الصورة أولًا، ثم حقل العربية وحقل الإنجليزية.
    final arabicField = find.byType(TextField).at(1);
    await tester.enterText(arabicField, 'قهوة الصباح');
    await tester.pump();

    expect(changed, contains('title_ar=قهوة الصباح'));
    expect(changed, isNot(contains('title_en=قهوة الصباح')));
  });

  testWidgets('the separate mode edits each language on its own', (
    tester,
  ) async {
    final changed = <String>[];
    await pumpPanel(tester, onKeyChanged: changed.add, onReset: (_) {});

    // دمج الزوج متاح لكنه اختيار صريح؛ الفصل هو الوضع الأول.
    await tester.tap(find.text(S.visualEditorBilingualBoth).first);
    await tester.pump();

    expect(find.text(S.visualEditorBilingualArabicLabel), findsOneWidget);
    expect(find.text(S.visualEditorBilingualEnglishLabel), findsOneWidget);
    // تسمية الحقل تبقى فوق الحقلين مع تسمية المجموعة.
    expect(find.text('العنوان'), findsNWidgets(2));

    // بعد الدمج: حقل الصورة ثم حقل العنوان الموحّد.
    final textFields = find.byType(TextField);
    expect(textFields, findsAtLeastNWidgets(2));
    await tester.enterText(textFields.at(1), 'Morning Coffee');
    await tester.pump();

    expect(
      changed,
      containsAll(['title_ar=Morning Coffee', 'title_en=Morning Coffee']),
    );
  });

  testWidgets('an image is previewed and can be removed', (tester) async {
    final changed = <String>[];
    final imageComponent = component.copyWith(
      properties: <String, dynamic>{
        ...component.properties,
        'imageUrl': 'https://example.invalid/current.png',
      },
    );
    await pumpPanel(
      tester,
      onKeyChanged: changed.add,
      onReset: (_) {},
      panelComponent: imageComponent,
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text(S.visualEditorRestoreOriginalImage), findsOneWidget);
    await tester.tap(find.text(S.visualEditorRestoreOriginalImage));
    await tester.pump();

    expect(changed, contains('imageUrl='));
    expect(find.text(S.visualEditorRestoreOriginalImage), findsNothing);
  });

  testWidgets('an image can be replaced by a picked upload', (tester) async {
    final changed = <String>[];
    final imageComponent = component.copyWith(
      properties: <String, dynamic>{
        ...component.properties,
        'imageUrl': 'https://example.invalid/current.png',
      },
    );
    await pumpPanel(
      tester,
      onKeyChanged: changed.add,
      onReset: (_) {},
      panelComponent: imageComponent,
      onPickImage: () async => 'https://example.invalid/replacement.png',
    );

    await tester.tap(find.text(S.visualEditorPickImage));
    await tester.pump();
    await tester.pump();

    expect(
      changed,
      contains('imageUrl=https://example.invalid/replacement.png'),
    );
  });

  testWidgets('an image can be chosen from the customer image library', (
    tester,
  ) async {
    final changed = <String>[];
    await pumpPanel(
      tester,
      onKeyChanged: changed.add,
      onReset: (_) {},
      onBrowseImages: () async => 'https://example.invalid/library.png',
    );

    await tester.tap(find.text(S.visualEditorImageLibrary).first);
    await tester.pump();

    expect(changed, contains('imageUrl=https://example.invalid/library.png'));
  });

  testWidgets('splash image can be selected from its library', (tester) async {
    final changed = <String>[];
    final splash = EditableComponent(
      componentId: 'splash_settings',
      componentType: 'splashSettings',
      pageId: 'splash',
      index: 0,
      classification: ComponentClassification.editable,
      properties: const {'imageUrl': '', 'visible': true},
      defaultValues: const {'imageUrl': ''},
      validationRules: const {},
      allowedOperations: const ['edit', 'hide'],
      version: 1,
    );
    await pumpPanel(
      tester,
      onKeyChanged: changed.add,
      onReset: (_) {},
      panelComponent: splash,
      onBrowseImages: () async => 'https://example.invalid/splash.png',
    );

    expect(find.text(S.visualEditorImageLibrary), findsOneWidget);
    expect(find.text(S.visualEditorSplashDefaultImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<AssetImage>(),
      reason: 'معاينة الافتتاحية تعرض الشعار الافتراضي قبل رفع صورة مخصصة',
    );

    await tester.tap(find.text(S.visualEditorImageLibrary));
    await tester.pump();
    expect(changed, contains('imageUrl=https://example.invalid/splash.png'));
    expect(find.text(S.visualEditorSplashCustomImage), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image).first).image,
      isA<NetworkImage>(),
      reason: 'يجب أن تتغير صورة المعاينة المصغرة فور اختيار الصورة من المكتبة',
    );

    await tester.tap(find.text(S.visualEditorRestoreOriginalImage));
    await tester.pump();
    expect(changed, contains('imageUrl='));

    await tester.tap(find.text(S.visualEditorHideImage));
    await tester.pump();
    expect(changed, contains('imageVisible=false'));

    final hiddenSplash = EditableComponent(
      componentId: 'splash_settings',
      componentType: 'splashSettings',
      pageId: 'splash',
      index: 0,
      classification: ComponentClassification.editable,
      properties: const {
        'imageUrl': '',
        'visible': true,
        'imageVisible': false,
      },
      defaultValues: const {'imageUrl': ''},
      validationRules: const {},
      allowedOperations: const ['edit', 'hide'],
      version: 1,
    );
    await pumpPanel(
      tester,
      onKeyChanged: changed.add,
      onReset: (_) {},
      panelComponent: hiddenSplash,
    );
    expect(find.text(S.visualEditorSplashImageHidden), findsOneWidget);
  });

  testWidgets('splash image can be replaced with an uploaded file', (
    tester,
  ) async {
    final changed = <String>[];
    final splash = EditableComponent(
      componentId: 'splash_settings',
      componentType: 'splashSettings',
      pageId: 'splash',
      index: 0,
      classification: ComponentClassification.editable,
      properties: const {'imageUrl': '', 'visible': true},
      defaultValues: const {'imageUrl': ''},
      validationRules: const {},
      allowedOperations: const ['edit', 'hide'],
      version: 1,
    );
    await pumpPanel(
      tester,
      onKeyChanged: changed.add,
      onReset: (_) {},
      panelComponent: splash,
      onPickImage: () async => 'https://example.invalid/uploaded-splash.png',
    );

    await tester.tap(find.text(S.visualEditorPickImage));
    await tester.pump();
    await tester.pump();

    expect(
      changed,
      contains('imageUrl=https://example.invalid/uploaded-splash.png'),
    );
    expect(find.text(S.visualEditorSplashCustomImage), findsOneWidget);
  });

  testWidgets('reset clears both languages at once', (tester) async {
    final resets = <String>[];
    await pumpPanel(tester, onKeyChanged: (_) {}, onReset: resets.add);

    // أول زر إعادة يخص حقل الصورة، والثاني زوج العنوان.
    final resetButtons = find.byTooltip(S.visualEditorResetProperty);
    await tester.tap(resetButtons.at(1));
    await tester.pump();

    expect(resets, containsAll(['title_ar', 'title_en']));
  });
}
