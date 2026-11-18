import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/pages/visual_editor_page.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_right_inspector.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// مستودع زائف مستقل: لا يلمس شبكة، ويجعل التهيئة تنجح فورًا.
class _FakeVisualEditorRepository implements VisualEditorRepository {
  int saveCalls = 0;
  final List<Map<String, dynamic>> publishedDocuments = [];

  @override
  Future<EditorDraft?> loadDraft() async => null;

  @override
  Future<DateTime> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
  }) async {
    saveCalls++;
    return DateTime(2026, 1, 1);
  }

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? note,
  }) async {
    publishedDocuments.add(designDocument);
    return PublishedVersionInfo(
      id: 'version-1',
      versionNumber: 1,
      publishedAt: DateTime(2026, 1, 2),
      schemaVersion: 2,
    );
  }

  @override
  Future<List<PublishedVersionInfo>> listVersions({int limit = 30}) async => [
    PublishedVersionInfo(
      id: 'version-1',
      versionNumber: 1,
      publishedAt: DateTime(2026, 1, 2),
      schemaVersion: 2,
    ),
  ];

  @override
  Future<Map<String, dynamic>?> getVersionDocument(String versionId) async =>
      null;

  @override
  Future<PublishedVersionInfo> restoreVersion(String versionId) async =>
      PublishedVersionInfo(
        id: 'version-2',
        versionNumber: 2,
        publishedAt: DateTime(2026, 1, 3),
        schemaVersion: 2,
      );

  @override
  Future<List<DesignTemplateInfo>> listTemplates() async => const [];

  @override
  Future<Map<String, dynamic>?> getTemplateDocument(String templateId) async =>
      null;

  @override
  Future<DesignTemplateInfo> saveTemplate({
    String? id,
    required String name,
    required Map<String, dynamic> document,
  }) async => DesignTemplateInfo(
    id: id ?? 'template-1',
    name: name,
    schemaVersion: 2,
    updatedAt: DateTime(2026, 1, 3),
  );

  @override
  Future<void> deleteTemplate(String templateId) async {}

  @override
  Future<void> discardDraft() async {}
}

/// اختبار توزيع واجهة المحرر: يمين (العنوان والصفحات والمكتبة)،
/// منتصف (المعاينة كاملة)، يسار (أدوات الجهاز والتحكم) — بلا قصّ.
VisualEditorPage _page({bool canPublish = true}) {
  return VisualEditorPage(
    cubit: VisualEditorCubit(repository: _FakeVisualEditorRepository()),
    canPublish: canPublish,
  );
}

EditableComponent _component(String type, Map<String, dynamic> properties) {
  return EditableComponent(
    componentId: 'test-$type',
    componentType: type,
    pageId: 'home',
    index: 0,
    classification: ComponentClassification.editable,
    properties: properties,
    defaultValues: const {},
    validationRules: const {},
    allowedOperations: const ['edit', 'delete'],
    version: 1,
  );
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: size.width,
        height: size.height,
        child: Scaffold(body: _page()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('خصائص المفتش تتغير مع نوع العنصر المحدد', (tester) async {
    ComponentRegistry.initialize();
    final changed = <String>[];

    Future<void> pumpInspector(EditableComponent component) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                VisualEditorRightInspector(
                  selectedComponent: component,
                  onPropertyChanged: ({
                    required componentId,
                    required propertyKey,
                    required value,
                  }) => changed.add(propertyKey),
                  onResetProperty: ({
                    required componentId,
                    required propertyKey,
                  }) {},
                  imagePermissions: const {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpInspector(_component('image', const {'imageUrl': ''}));
    expect(find.text('طريقة العرض'), findsOneWidget);
    expect(find.text('وزن الخط'), findsNothing);
    expect(find.text('تخصيص ألوان الخلفية، الشفافية، والظهور'), findsNothing);

    await pumpInspector(
      _component('text', const {'text_ar': '', 'text_en': ''}),
    );
    expect(find.text('وزن الخط'), findsOneWidget);
    expect(find.text('اتجاه الكتابة'), findsOneWidget);
    expect(find.text('تباعد الحروف'), findsOneWidget);
    expect(find.text('تجاوز النص'), findsOneWidget);
    expect(find.text('طريقة العرض'), findsNothing);
  });

  testWidgets('العرض العريض: لوحات الأطراف والمعاينة في المنتصف كلها موجودة', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1400, 900));

    // الجانب الأيمن (RTL أول عمود): العنوان + قائمة الصفحات.
    expect(find.text('صفحات تطبيق العميل'), findsOneWidget);
    // الجانب الأيسر: أدوات الجهاز والمعاينة.
    expect(find.text('الجهاز والمعاينة'), findsOneWidget);
    // المنتصف: المعاينة.
    expect(find.byType(PreviewPanel), findsOneWidget);
    // الشريط العلوي يحمل أدوات لغة ومظهر معاينة العميل.
    expect(find.byTooltip(S.visualEditorPreviewLanguage), findsOneWidget);
    expect(find.byTooltip(S.visualEditorPreviewTheme), findsOneWidget);
    // قائمة الصفحات: رقائق متعددة (الجرد الكامل).
    expect(
      find.byType(ChoiceChip),
      findsNWidgets(37),
      reason: 'كل شاشات التطبيق يجب أن تظهر في قائمة الصفحات',
    );
    // كل أدوات الشريط السابق موجودة في العمود الأيسر:
    expect(find.byType(EditorScreenSizeSelector), findsOneWidget);
    expect(find.byType(EditorZoomControls), findsOneWidget);
    expect(find.byType(EditorConnectionStatus), findsOneWidget);
    // لوحة الخصائص تظهر في الجانب الأيسر.
    expect(find.byType(VisualEditorRightInspector), findsOneWidget);
  });

  testWidgets('حساب محرر التصميم لا ينشر أو يسترجع بلا صلاحية النشر', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _page(canPublish: false))),
    );
    await tester.pumpAndSettle();

    final publishButton = tester.widget<EditorToolbarButton>(
      find.ancestor(
        of: find.text(S.visualEditorPublish),
        matching: find.byType(EditorToolbarButton),
      ),
    );
    expect(publishButton.onTap, isNull);

    await tester.tap(find.byTooltip(S.visualEditorVersions));
    await tester.pumpAndSettle();
    final restoreButton = tester.widget<TextButton>(
      find.ancestor(
        of: find.text(S.visualEditorRestore),
        matching: find.byType(TextButton),
      ),
    );
    expect(restoreButton.onPressed, isNull);
  });

  testWidgets('سحب مكوّن إلى المعاينة ثم حفظه ونشره من الواجهة', (
    tester,
  ) async {
    ComponentRegistry.initialize();
    final repository = _FakeVisualEditorRepository();
    final cubit = VisualEditorCubit(repository: repository);
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualEditorPage(cubit: cubit, canPublish: true)),
      ),
    );
    await tester.pumpAndSettle();

    final libraryCard = find.text('شبكة منتجات');
    expect(libraryCard, findsOneWidget);
    await tester.ensureVisible(libraryCard);
    await tester.pumpAndSettle();
    final preview = find.byType(PreviewPanel);
    final start = tester.getCenter(libraryCard);
    final end = tester.getCenter(preview);
    final gesture = await tester.startGesture(start);
    await tester.pump();
    for (var step = 1; step <= 12; step++) {
      await gesture.moveTo(Offset.lerp(start, end, step / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('أفلت المكوّن لإضافته إلى الصفحة'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      cubit.state
          .getComponentsForPage('home')
          .where((component) => component.componentType == 'productGrid'),
      hasLength(1),
    );
    expect(cubit.state.isDirty, isTrue);

    final saveButton = find
        .ancestor(
          of: find.text(S.visualEditorSaveDraft).first,
          matching: find.byType(EditorToolbarButton),
        )
        .first;
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 1);
    expect(cubit.state.isDirty, isFalse);

    final publishButton = find
        .ancestor(
          of: find.text(S.visualEditorPublish).first,
          matching: find.byType(EditorToolbarButton),
        )
        .first;
    await tester.tap(publishButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, S.visualEditorPublish));
    await tester.pumpAndSettle();

    expect(repository.publishedDocuments, hasLength(1));
    final publishedPage =
        (repository.publishedDocuments.single['pages'] as List)
            .whereType<Map<String, dynamic>>()
            .firstWhere((page) => page['page'] == 'home');
    final root = publishedPage['root'] as Map<String, dynamic>;
    final children = root['children'] as List<dynamic>;
    expect(
      children.whereType<Map<String, dynamic>>().any(
        (node) => node['type'] == 'section.product_grid',
      ),
      isTrue,
    );
    await cubit.close();
  });

  testWidgets('العرض المتوسط: نفس التوزيع الثلاثي بأعمدة أضيق', (tester) async {
    await _pumpAt(tester, const Size(1024, 800));
    expect(find.text('صفحات تطبيق العميل'), findsOneWidget);
    expect(find.text('الجهاز والمعاينة'), findsOneWidget);
    expect(find.byType(PreviewPanel), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(37));
  });

  testWidgets('العرض الضيق: المعاينة ثم الصفحات ثم الأدوات ثم اللوحات', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(600, 800));
    // المعاينة موجودة والشريط الأفقي يبقى (كل الأدوات لا تُفقد).
    expect(find.byType(PreviewPanel), findsOneWidget);
    expect(find.byType(VisualEditorToolbar), findsOneWidget);
    // أدوات المعاينة نفسها تنتقل إلى الشريط الضيق فلا تُفقد.
    expect(find.byTooltip(S.visualEditorPreviewLanguage), findsOneWidget);
    expect(find.byTooltip(S.visualEditorPreviewTheme), findsOneWidget);
    // رقائق الصفحات (شريط أفقي في الضيق) برقائق متعددة.
    expect(find.byType(ChoiceChip), findsWidgets);
  });
}
