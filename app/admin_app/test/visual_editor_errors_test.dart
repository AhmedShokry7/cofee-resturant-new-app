import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/pages/visual_editor_page.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/templates_dialog.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/theme_studio_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// رفض النشر كان يُكتب في الحالة ولا يُعرض: الشاشة تبقى جاهزة والقشرة لا
/// تقرأ إلا خطأ الحالة الكامل، فيضغط الموظف «نشر» ولا يعرف السبب أبدًا.
class _RejectingRepository extends VisualEditorRepository {
  _RejectingRepository(this.error);

  final String error;

  @override
  Future<EditorDraft?> loadDraft() async => null;

  @override
  Future<PageSaveResult> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
    Map<String, int> knownRevisions = const {},
    bool force = false,
  }) async =>
      PageSaveResult(savedRevisions: const {}, savedAt: DateTime(2026, 1, 1));

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? name,
    String? note,
  }) async => throw StateError('design document cannot be published: $error');

  @override
  Future<PublishedVersionInfo> publishPages({
    required Set<String> pageIds,
    Map<String, int> knownRevisions = const {},
    bool force = false,
    String? name,
    String? note,
  }) async => throw StateError('design document cannot be published: $error');

  @override
  Future<List<PublishedVersionInfo>> listVersions({int limit = 30}) async =>
      const [];

  @override
  Future<Map<String, dynamic>?> getVersionDocument(String versionId) async =>
      null;

  @override
  Future<PublishedVersionInfo> restoreVersion(String versionId) async =>
      throw UnimplementedError();

  @override
  Future<void> updateVersionDetails(
    String versionId,
    String? name,
    String? note,
  ) async {}

  @override
  Future<void> deleteVersion(String versionId) async {}

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
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteTemplate(String templateId) async {}

  @override
  Future<void> discardDraft() async {}
}

Future<void> pumpEditor(WidgetTester tester, VisualEditorCubit cubit) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: VisualEditorPage(cubit: cubit)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('رفض النشر يظهر للموظف برسالة تشرح ما يفعله', (tester) async {
    final cubit = VisualEditorCubit(
      repository: _RejectingRepository('page_key'),
    );
    await pumpEditor(tester, cubit);

    await cubit.publish();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.textContaining('migration 244'),
      findsOneWidget,
      reason: 'رمز page_key الخام لا يقول للموظف شيئًا',
    );
  });

  testWidgets('رفض صلاحية النشر يشرح الصلاحية المطلوبة', (tester) async {
    final cubit = VisualEditorCubit(
      repository: _RejectingRepository('missing permission: design.publish'),
    );
    await pumpEditor(tester, cubit);

    await cubit.publish();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('design.publish'), findsOneWidget);
  });

  testWidgets('رمز رفض غير معروف يُعرض كما ردّت القاعدة', (tester) async {
    final cubit = VisualEditorCubit(
      repository: _RejectingRepository('some_new_code'),
    );
    await pumpEditor(tester, cubit);

    await cubit.publish();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('some_new_code'), findsOneWidget);
  });

  group('حوارات المحرر', () {
    testWidgets('فتح القوالب لا يسقط بغياب المزوّد في مسار الحوار', (
      tester,
    ) async {
      final cubit = VisualEditorCubit(
        repository: _RejectingRepository('page_key'),
      );
      await pumpEditor(tester, cubit);

      await tester.tap(find.byTooltip('Templates'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplatesDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('فتح استوديو الثيم لا يسقط بغياب المزوّد في مسار الحوار', (
      tester,
    ) async {
      final cubit = VisualEditorCubit(
        repository: _RejectingRepository('page_key'),
      );
      await pumpEditor(tester, cubit);

      await tester.ensureVisible(
        find.byKey(const ValueKey('studio-tool-identity')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-tool-identity')));
      await tester.pumpAndSettle();

      expect(find.byType(ThemeStudioDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
