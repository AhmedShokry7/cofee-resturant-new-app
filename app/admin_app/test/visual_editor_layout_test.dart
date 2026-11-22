import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/pages/visual_editor_page.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/studio_single_row_toolbar.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_right_inspector.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// مستودع زائف مستقل: لا يلمس شبكة، ويجعل التهيئة تنجح فورًا.
class _FakeVisualEditorRepository extends VisualEditorRepository {
  _FakeVisualEditorRepository({this.rejectPublish = false});

  final bool rejectPublish;
  int saveCalls = 0;
  final List<Map<String, dynamic>> publishedDocuments = [];

  @override
  Future<EditorDraft?> loadDraft() async => null;

  @override
  Future<PageSaveResult> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
    Map<String, int> knownRevisions = const {},
    bool force = false,
  }) async {
    saveCalls++;
    return PageSaveResult(
      savedRevisions: {
        for (var i = 0; i < componentsByPage.keys.length; i++)
          componentsByPage.keys.elementAt(i): i + 1,
      },
      savedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? name,
    String? note,
  }) async {
    if (rejectPublish) {
      throw StateError('missing permission: design.publish');
    }
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

/// اختبار توزيع واجهة المحرر: شريط أدوات واحد علوي، ثم لوحة الطبقات
/// والمسرح والمفتش في العرض العريض، وأزرار طافية في العرض الضيق — بلا قصّ.
VisualEditorPage _page({bool canPublish = true}) {
  return VisualEditorPage(
    cubit: VisualEditorCubit(repository: _FakeVisualEditorRepository()),
    canPublish: canPublish,
  );
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
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
  testWidgets('العرض العريض: شريط الأدوات واللوحات والمعاينة كلها موجودة', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1400, 900));

    // شريط الأدوات العلوي بحتوائه كاملًا.
    expect(find.byType(StudioSingleRowToolbar), findsOneWidget);
    expect(find.text(S.studioTitle), findsOneWidget);
    expect(find.text(S.visualEditorPublish), findsOneWidget);
    expect(find.byTooltip(S.visualEditorPreviewLanguage), findsOneWidget);
    expect(find.byTooltip(S.visualEditorPreviewTheme), findsOneWidget);
    // المنتصف: المعاينة الحيّة.
    expect(find.byType(PreviewPanel), findsOneWidget);
    // لوحة الطبقات والمفتش على الأطراف.
    expect(find.text(S.visualEditorLayers), findsOneWidget);
    expect(find.byType(VisualEditorRightInspector), findsOneWidget);
  });

  testWidgets('حساب محرر التصميم لا ينشر بلا صلاحية النشر', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _FakeVisualEditorRepository(rejectPublish: true);
    final cubit = VisualEditorCubit(repository: repository);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        home: Scaffold(body: VisualEditorPage(cubit: cubit, canPublish: false)),
      ),
    );
    await tester.pumpAndSettle();

    final publishButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('studio-tool-publish')),
        matching: find.byType(TextButton),
      ),
    );
    expect(publishButton.onPressed, isNull);
    expect(repository.publishedDocuments, isEmpty);
  });

  testWidgets('العرض المتوسط: نفس التوزيع الثلاثي بأعمدة أضيق', (tester) async {
    await _pumpAt(tester, const Size(1024, 800));
    expect(find.byType(StudioSingleRowToolbar), findsOneWidget);
    expect(find.text(S.studioTitle), findsOneWidget);
    expect(find.byType(PreviewPanel), findsOneWidget);
    // اللوحات طافية في العرض المتوسط: خصائص تظهر بعد فتحها.
    expect(find.byTooltip(S.visualEditorProperties), findsOneWidget);
    await tester.tap(find.byTooltip(S.visualEditorProperties));
    await tester.pumpAndSettle();
    expect(find.byType(VisualEditorRightInspector), findsOneWidget);
  });

  testWidgets('العرض الضيق: المعاينة وأزرار اللوحات الطافية', (tester) async {
    await _pumpAt(tester, const Size(600, 800));
    // المعاينة موجودة والشريط الأفقي يبقى (كل الأدوات لا تُفقد).
    expect(find.byType(PreviewPanel), findsOneWidget);
    expect(find.byType(StudioSingleRowToolbar), findsOneWidget);
    // أدوات المعاينة نفسها تبقى متاحة في الشريط الضيق.
    expect(find.byTooltip(S.visualEditorPreviewLanguage), findsOneWidget);
    expect(find.byTooltip(S.visualEditorPreviewTheme), findsOneWidget);
    // أزرار اللوحات الطافية للطبقات والخصائص.
    expect(find.byTooltip(S.visualEditorLayers), findsOneWidget);
    expect(find.byTooltip(S.visualEditorProperties), findsOneWidget);
  });

  testWidgets('لوحة الطبقات تفتح في العرض الضيق وتغلق الخصائص', (tester) async {
    ComponentRegistry.initialize();
    await _pumpAt(tester, const Size(600, 800));

    await tester.tap(find.byTooltip(S.visualEditorLayers));
    await tester.pumpAndSettle();
    // اللوحة الطافية مفتوحة تعرض شريط بحثها فوق المسرح.
    expect(find.text('ابحث في العناصر…'), findsOneWidget);
  });
}
