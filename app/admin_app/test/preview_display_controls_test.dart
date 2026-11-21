import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_display_controls.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// مستودع صامت: أدوات العرض لا تقرأ ولا تكتب مسودة، فلا حاجة لاتصال حقيقي.
class _NoopRepository extends VisualEditorRepository {
  @override
  Future<EditorDraft?> loadDraft() async => null;

  @override
  Future<DateTime> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
  }) async => DateTime(2026, 1, 1);

  @override
  Future<void> discardDraft() async {}

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? name,
    String? note,
  }) async => PublishedVersionInfo(
    id: 'v1',
    versionNumber: 1,
    publishedAt: DateTime(2026, 1, 1),
    schemaVersion: 2,
  );

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
  }) async => DesignTemplateInfo(
    id: id ?? 't1',
    name: name,
    schemaVersion: 2,
    updatedAt: DateTime(2026, 1, 1),
  );

  @override
  Future<void> deleteTemplate(String templateId) async {}
}

void main() {
  test('رابط الإطار يحمل لغة ووضع المعاينة في كل تحميل', () {
    final defaults = Uri.parse(
      buildPreviewUrl('ve_1', 'https://admin.example'),
    );
    expect(defaults.queryParameters['mode'], 'preview');
    expect(defaults.queryParameters['sessionId'], 've_1');
    expect(defaults.queryParameters['language'], 'ar');
    expect(defaults.queryParameters['theme'], 'light');

    final chosen = Uri.parse(
      buildPreviewUrl(
        've_1',
        'https://admin.example',
        language: PreviewLanguage.english,
        themeMode: PreviewThemeMode.dark,
      ),
    );
    expect(chosen.queryParameters['language'], 'en');
    expect(chosen.queryParameters['theme'], 'dark');
    expect(chosen.queryParameters['parentOrigin'], 'https://admin.example');
  });

  testWidgets('زرا المعاينة يبدّلان لغة العميل ووضعه بلا لمس المسودة', (
    tester,
  ) async {
    final cubit = VisualEditorCubit(repository: _NoopRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<VisualEditorCubit>.value(
            value: cubit,
            child: BlocBuilder<VisualEditorCubit, VisualEditorState>(
              builder: (context, state) =>
                  PreviewDisplayControls(state: state, cubit: cubit),
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip(S.visualEditorPreviewLanguage), findsOneWidget);
    expect(find.byTooltip(S.visualEditorPreviewTheme), findsOneWidget);
    expect(find.text('AR'), findsOneWidget);
    expect(find.byIcon(AppIcons.sun03), findsOneWidget);

    await tester.tap(find.byTooltip(S.visualEditorPreviewLanguage));
    await tester.pump();
    expect(cubit.state.previewLanguage, PreviewLanguage.english);
    expect(find.text('EN'), findsOneWidget);

    await tester.tap(find.byTooltip(S.visualEditorPreviewTheme));
    await tester.pump();
    expect(cubit.state.previewThemeMode, PreviewThemeMode.dark);
    expect(find.byIcon(AppIcons.moon01), findsOneWidget);

    expect(cubit.state.isDirty, isFalse);
    expect(cubit.canUndo, isFalse);
  });
}
