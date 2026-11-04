import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_template.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_version.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/app_builder_repository.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_cubit.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_state.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_status_panel.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

/// لوحة لا تملك ما يرفضه الخادم: الزرّ المطفأ يسمّى سببه، والسبب مختلف لمن
/// لا يملك الصلاحية عن نفسه لمن شجرته بها مانع.
///
/// هذه ليست حماية — 226 ترفض الكتابة بـ 42501 مهما فعلت الواجهة — بل عدم ترك
/// الموظف يظن أن العيب في تصميمه.
class _NoopRepository implements AppBuilderRepository {
  @override
  Future<DesignDocument?> loadDraft() async => null;

  @override
  Future<DesignDocument?> loadPublished() async => null;

  @override
  Future<List<DesignVersion>> loadVersions() async => const <DesignVersion>[];

  @override
  Future<DesignDocument?> loadVersion(String versionId) async => null;

  @override
  Future<void> saveDraft(DesignDocument document) async {}

  @override
  Future<DesignVersion> publish(DesignDocument document) async =>
      throw UnimplementedError();

  @override
  Future<DesignVersion> restoreVersion(String versionId) async =>
      throw UnimplementedError();

  @override
  Future<void> discardDraft() async {}

  @override
  Future<List<DesignTemplate>> loadTemplates() async =>
      const <DesignTemplate>[];

  @override
  Future<DesignDocument?> loadTemplate(String id) async => null;

  @override
  Future<DesignTemplate> saveTemplate(
    String name,
    DesignDocument document, {
    String? templateId,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteTemplate(String id) async {}
}

final _state = AppBuilderState(
  status: AppBuilderStatus.ready,
  document: WidgetRegistry.defaultDocument(),
);

final _published = DateTime.utc(2026, 11, 3, 9);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

AdminToolbarButton _button(WidgetTester tester, String label) => tester
    .widget<AdminToolbarButton>(find.widgetWithText(AdminToolbarButton, label));

void main() {
  final cubit = AppBuilderCubit(repository: _NoopRepository());

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  BuilderToolbar toolbarUnderTest({
    required bool canEdit,
    required bool canPublish,
  }) => BuilderToolbar(
    state: _state,
    cubit: cubit,
    zoom: 1,
    canEdit: canEdit,
    canPublish: canPublish,
    onZoom: (_) {},
  );

  testWidgets('بلا صلاحية نشر: الزرّ ميت والتلميح يسمّي الصلاحية', (
    tester,
  ) async {
    await _pump(tester, toolbarUnderTest(canEdit: true, canPublish: false));

    expect(_button(tester, S.builderPublish).onPressed, isNull);
    expect(find.byTooltip(S.builderPublishNeedsPermission), findsOneWidget);
    // التحرير لم يُمسّ: من يملك design.edit يحفظ مسودته كما كان.
    expect(_button(tester, S.builderSave).onPressed, isNotNull);
  });

  testWidgets('بلا صلاحية تحرير: النشر والحفظ والتجاهل كلها معطلة', (
    tester,
  ) async {
    await _pump(tester, toolbarUnderTest(canEdit: false, canPublish: true));

    expect(_button(tester, S.builderSave).onPressed, isNull);
    expect(_button(tester, S.builderDiscard).onPressed, isNull);
    expect(_button(tester, S.builderPublish).onPressed, isNull);
    expect(find.byTooltip(S.builderPublishNeedsEdit), findsOneWidget);
  });

  testWidgets('بالصلاحين وعلى شجرة صالحة: النشر يعمل', (tester) async {
    await _pump(tester, toolbarUnderTest(canEdit: true, canPublish: true));

    expect(_state.canPublish, isTrue, reason: 'المخطط الافتراضي صالح للنشر');
    expect(_button(tester, S.builderPublish).onPressed, isNotNull);
    expect(find.byTooltip(S.builderPublish), findsOneWidget);
  });

  testWidgets('وضع المشاهدة لا ينشر ولو بالصلاحية', (tester) async {
    await _pump(
      tester,
      BuilderToolbar(
        state: _state.copyWith(mode: AppBuilderMode.preview),
        cubit: cubit,
        zoom: 1,
        canEdit: true,
        canPublish: true,
        onZoom: (_) {},
      ),
    );

    expect(_button(tester, S.builderPublish).onPressed, isNull);
    expect(find.byTooltip(S.builderPublishNeedsEdit), findsOneWidget);
  });

  testWidgets('الرجوع إلى إصدار نشر: بصلاحية النشر لا بصلاحية التحرير', (
    tester,
  ) async {
    Widget panel(bool canRestore) => BuilderStatusPanel(
      page: AppPage.home,
      validation: _state.validation,
      versions: <DesignVersion>[
        DesignVersion(
          id: 'v1',
          number: 4,
          publishedAt: _published,
          schemaVersion: 1,
        ),
      ],
      inspectedVersionId: null,
      busy: false,
      canRestore: canRestore,
      onInspect: (_) {},
      onRestore: (_) {},
    );

    await _pump(tester, panel(false));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, S.builderRestore))
          .onPressed,
      isNull,
    );
    expect(find.byTooltip(S.builderPublishNeedsPermission), findsOneWidget);

    await _pump(tester, panel(true));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, S.builderRestore))
          .onPressed,
      isNotNull,
    );
  });
}
