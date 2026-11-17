import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/pages/visual_editor_page.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// مستودع زائف مستقل: لا يلمس شبكة، ويجعل التهيئة تنجح فورًا.
class _FakeVisualEditorRepository implements VisualEditorRepository {
  @override
  Future<EditorDraft?> loadDraft() async => null;

  @override
  Future<DateTime> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
  }) async => DateTime(2026, 1, 1);

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? note,
  }) async => PublishedVersionInfo(
    id: 'version-1',
    versionNumber: 1,
    publishedAt: DateTime(2026, 1, 2),
    schemaVersion: 2,
  );

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
    // تبويبات الطبقات/الخصائص في الجانب الأيسر (النص يعتمد اللغة —
    // نتحقق من وجود التبويبات نفسها).
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
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
    // رقائق الصفحات (شريط أفقي في الضيق) برقائق متعددة.
    expect(find.byType(ChoiceChip), findsWidgets);
  });
}
