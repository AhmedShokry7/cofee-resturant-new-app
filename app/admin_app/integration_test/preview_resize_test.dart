import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/pages/visual_editor_page.dart';

/// Reproduces the reported breakage: the live preview works at a small
/// window, then stops once the window is enlarged (the editor switches
/// between its narrow / medium / wide layouts at 900 and 1400 px).
///
/// Pumps the real VisualEditorPage with a fake repository at each size and
/// reports the preview connection state the editor itself records.
class _FakeVisualEditorRepository implements VisualEditorRepository {
  @override
  Future<EditorDraft?> loadDraft() async => null;

  @override
  Future<DateTime> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
  }) async =>
      DateTime(2026, 1, 1);

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? note,
  }) async =>
      PublishedVersionInfo(
        id: 'version-1',
        versionNumber: 1,
        publishedAt: DateTime(2026, 1, 2),
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
      PublishedVersionInfo(
        id: 'version-2',
        versionNumber: 2,
        publishedAt: DateTime(2026, 1, 3),
        schemaVersion: 2,
      );

  @override
  Future<List<DesignTemplateInfo>> listTemplates() async => const [];

  @override
  Future<Map<String, dynamic>?> getTemplateDocument(
    String templateId,
  ) async =>
      null;

  @override
  Future<DesignTemplateInfo> saveTemplate({
    String? id,
    required String name,
    required Map<String, dynamic> document,
  }) async =>
      DesignTemplateInfo(
        id: id ?? 'template-1',
        name: 'template',
        schemaVersion: 2,
        updatedAt: DateTime(2026, 1, 3),
      );

  @override
  Future<void> deleteTemplate(String templateId) async {}

  @override
  Future<void> discardDraft() async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preview survives the editor layout switches', (tester) async {
    print('PROBE FLUTTER_TEST env: '
        '${const String.fromEnvironment('FLUTTER_TEST')} / '
        '${binding.runtimeType}');
    AppLocale.instance.debugSet(AppLanguage.arabic);

    final cubit = VisualEditorCubit(repository: _FakeVisualEditorRepository());

    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: VisualEditorPage(cubit: cubit),
              ),
            ),
          ),
        ),
      );
      // Real async: give the WebView2 controller and the customer app time.
      for (var i = 0; i < 15; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump();
      }
      print('PROBE size=${size.width}x${size.height} '
          'connection=${cubit.state.previewConnection}');
    }

    await pumpAt(const Size(800, 900)); // narrow: the size that works
    await pumpAt(const Size(1200, 900)); // medium
    await pumpAt(const Size(1500, 900)); // wide

    expect(cubit.state.previewConnection, PreviewConnection.connected,
        reason: 'the preview must come back connected after enlarging');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
