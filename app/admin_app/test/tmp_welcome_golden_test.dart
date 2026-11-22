import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as fl;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/pages/visual_editor_page.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/studio_single_row_toolbar.dart';
import 'package:material_ui/material_ui.dart' as mui;

class _Repo extends VisualEditorRepository {
  _Repo(this.draftDocument);

  final Map<String, dynamic> draftDocument;

  @override
  Future<EditorDraft?> loadDraft() async => EditorDraft(
    componentsByPage: DesignDocumentCodec.parseDocument(draftDocument),
    theme: DesignDocumentCodec.themeOf(draftDocument),
    savedAt: DateTime(2026, 1, 1),
  );

  @override
  Future<PageSaveResult> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
    Map<String, int> knownRevisions = const {},
    bool force = false,
  }) async => PageSaveResult(
    savedRevisions: const {},
    savedAt: DateTime(2026, 1, 1),
  );

  @override
  Future<Map<String, dynamic>?> loadDraftDocument() async => draftDocument;

  @override
  Future<Map<String, dynamic>?> loadPublishedDocument() async => null;

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
      throw UnimplementedError();

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
    id: 't1',
    name: name,
    schemaVersion: 2,
    updatedAt: DateTime(2026, 1, 3),
  );

  @override
  Future<void> deleteTemplate(String templateId) async {}
}

void main() {
  testWidgets('welcome editor screenshot', (tester) async {
    ComponentRegistry.initialize();
    ComponentRegistry.all.forEach(DesignDocumentCodec.registerEntry);
    AppLocale.instance.debugSet(AppLanguage.arabic);

    final document = DesignDocumentCodec.document(
      {'welcome': DesignDocumentCodec.defaultComponentsFor('welcome')},
    );

    final cubit = VisualEditorCubit(repository: _Repo(document));
    await cubit.initialize();
    cubit.loadPage('welcome');

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      mui.MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: mui.GlobalMaterialLocalizations.delegates,
        home: mui.Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: VisualEditorPage(cubit: cubit),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // بدّل الصفحة عبر استدعاء onPagaged من الشريط نفسه (نفس مسار اختيار
    // الصفحة من القائمة — initState يعيد التهيئة فتعود المعاينة للرئيسية).
    tester
        .widget<StudioSingleRowToolbar>(
          find.byType(StudioSingleRowToolbar),
        )
        .onPageChanged!('welcome');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    await expectLater(
      find.byType(VisualEditorPage),
      matchesGoldenFile('goldens/welcome_editor_full.png'),
    );
  }, skip: Platform.environment['GOLDENS'] != '1');
}
