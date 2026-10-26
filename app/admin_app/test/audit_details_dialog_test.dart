import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_details_dialog.dart';

AdminAuditLog _log({
  Map<String, dynamic>? oldValues = const {
    'name_ar': 'فرع المعادي',
    'name_en': 'Maadi branch',
    'is_active': true,
  },
  Map<String, dynamic>? newValues = const {
    'name_ar': 'فرع المعادي الجديد',
    'name_en': 'Maadi branch',
    'is_active': false,
  },
  String? actorName = 'Mona Ali',
  String? actorUserId = 'u1',
  String? actorEmail = 'mona@example.com',
}) => AdminAuditLog(
  id: 7,
  action: 'core.branch.update',
  entityType: 'branch',
  entityId: 'entity-1-123456',
  actorUserId: actorUserId,
  actorName: actorName,
  actorEmail: actorEmail,
  actorRolesAr: const ['مدير فرع'],
  actorRolesEn: const ['Branch manager'],
  branchNameAr: 'فرع المعادي',
  branchNameEn: 'Maadi branch',
  oldValues: oldValues,
  newValues: newValues,
  createdAt: DateTime.utc(2026, 10, 24, 9, 15),
);

void _setViewport(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpDialog(
  WidgetTester tester,
  AdminAuditLog log, {
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open-audit-dialog'),
              onPressed: () =>
                  showAuditDetailsDialog(context: context, log: log),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-audit-dialog')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the dialog explains who did what, where and when', (
    tester,
  ) async {
    await _pumpDialog(tester, _log());

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('audit-details-dialog')), findsOneWidget);
    expect(find.text(S.auditDetailsTitle), findsOneWidget);
    expect(find.text(S.auditDetailsSubtitle(7)), findsOneWidget);
    expect(
      find.text('${S.auditActionBranchUpdate} • Maadi branch'),
      findsWidgets,
    );

    expect(find.text(S.auditDetailsActor), findsOneWidget);
    expect(find.text('Mona Ali'), findsOneWidget);
    expect(find.text('mona@example.com'), findsOneWidget);
    expect(find.text('Branch manager'), findsWidgets);

    expect(find.text(S.auditDetailsWhen), findsOneWidget);
    expect(find.text('Maadi branch'), findsWidgets);

    expect(find.text(S.auditDetailsEntity), findsOneWidget);
    expect(find.text(S.auditEntityBranch), findsWidgets);
    expect(find.text('#entity-1…'), findsOneWidget);

    expect(find.text(S.auditDetailsChanges), findsOneWidget);
    expect(find.byKey(const Key('audit-change-name_ar')), findsOneWidget);
    expect(find.byKey(const Key('audit-change-is_active')), findsOneWidget);
    expect(find.byKey(const Key('audit-change-name_en')), findsNothing);
    expect(find.text(S.auditFieldNameAr), findsOneWidget);
    expect(find.text('فرع المعادي'), findsWidgets);
    expect(find.text('فرع المعادي الجديد'), findsWidgets);
    expect(find.text(S.activeStatus), findsOneWidget);
    expect(find.text(S.inactiveStatus), findsOneWidget);
  });

  testWidgets('technical audit data stays behind a disclosure', (tester) async {
    _setViewport(tester, 900, 1000);
    await _pumpDialog(tester, _log());

    expect(find.text('core.branch.update'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('audit-technical-section')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audit-technical-section')));
    await tester.pumpAndSettle();

    expect(find.text('core.branch.update'), findsOneWidget);
    expect(find.text('branch'), findsWidgets);
    expect(find.text('entity-1-123456'), findsOneWidget);
    expect(find.textContaining('"name_ar"'), findsWidgets);
  });

  testWidgets('an event without recorded changes says so', (tester) async {
    await _pumpDialog(tester, _log(oldValues: null, newValues: null));

    expect(tester.takeException(), isNull);
    expect(find.text(S.auditDetailsNoChanges), findsOneWidget);
    expect(find.text(S.auditDetailsChanges), findsOneWidget);
  });

  testWidgets('a system event has no actor but still reads clearly', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      _log(actorName: null, actorUserId: null, actorEmail: null),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.auditSystemActor), findsWidgets);
    expect(find.text(S.auditDetailsActor), findsOneWidget);
  });

  testWidgets('the Arabic right-to-left dialog fits a phone', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 420, 900);
    await _pumpDialog(tester, _log(), direction: TextDirection.rtl);

    expect(tester.takeException(), isNull);
    expect(find.text(S.auditDetailsTitle), findsOneWidget);
    expect(find.text('مدير فرع'), findsWidgets);
    expect(find.text(S.auditDetailsBefore), findsWidgets);
    expect(find.text(S.auditDetailsAfter), findsWidgets);
  });

  testWidgets('the dialog closes from its footer', (tester) async {
    await _pumpDialog(tester, _log());

    await tester.tap(find.byKey(const Key('audit-details-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audit-details-dialog')), findsNothing);
  });
}
