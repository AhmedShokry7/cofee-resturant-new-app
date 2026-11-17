import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('the Arabic and English fields merge into one bilingual field', (
    tester,
  ) async {
    final changed = <String>[];
    await pumpPanel(tester, onKeyChanged: changed.add, onReset: (_) {});

    // حقلان منفصلان بعنوانين «بالعربي/بالإنجليزي» لا ظهور لهما افتراضيًا:
    // الوجه الأول الحقل الواحد، وكتابته يغيّر اللغتين معًا.
    expect(find.text('العنوان بالعربي'), findsNothing);
    expect(find.text('العنوان بالإنجليزي'), findsNothing);
    // مرة لتسمية الحقل ومرة لتسمية مجموعة العنوان.
    expect(find.text('العنوان'), findsNWidgets(2));
  });

  testWidgets('typing in the merged field writes both languages', (
    tester,
  ) async {
    final changed = <String>[];
    await pumpPanel(tester, onKeyChanged: changed.add, onReset: (_) {});

    // أول TextField هو حقل الصورة، والثاني هو حقل العنوان الموحّد.
    final field = find.byType(TextField).at(1);
    await tester.enterText(field, 'قهوة الصباح');
    await tester.pump();

    expect(
      changed,
      containsAll(['title_ar=قهوة الصباح', 'title_en=قهوة الصباح']),
    );
  });

  testWidgets('the separate mode edits each language on its own', (
    tester,
  ) async {
    final changed = <String>[];
    await pumpPanel(tester, onKeyChanged: changed.add, onReset: (_) {});

    // زر الفصل موجود لكل زوج ثنائي (العنوان والوصف): الأول زوج العنوان.
    await tester.tap(find.text(S.visualEditorBilingualSeparate).first);
    await tester.pump();

    expect(find.text(S.visualEditorBilingualArabicLabel), findsOneWidget);
    expect(find.text(S.visualEditorBilingualEnglishLabel), findsOneWidget);
    // تسمية الحقل تبقى فوق الحقلين مع تسمية المجموعة.
    expect(find.text('العنوان'), findsNWidgets(2));

    // بعد فتح الفصل: حقل الصورة ثم العنوان بالعربي ثم العنوان بالإنجليزي.
    final textFields = find.byType(TextField);
    expect(textFields, findsAtLeastNWidgets(3));
    await tester.enterText(textFields.at(2), 'Morning Coffee');
    await tester.pump();

    expect(changed, contains('title_en=Morning Coffee'));
    expect(changed, isNot(contains('title_en=قهوة الصباح')));
    // العربي لم يُكتب في هذه الكتابة.
    expect(changed.where((c) => c.startsWith('title_ar=')), isEmpty);
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
    await tester.tap(find.text(S.visualEditorImageLibrary));
    await tester.pump();

    expect(changed, contains('imageUrl=https://example.invalid/splash.png'));
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
