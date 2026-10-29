import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/models/staff_filter.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_page_body.dart';

AdminStaffMember _member(int index) => AdminStaffMember(
  id: 's$index',
  userId: 'u$index',
  fullName: 'Staff $index',
  email: 'staff$index@example.com',
  status: index == 2
      ? 'invited'
      : index == 3
      ? 'suspended'
      : 'active',
  createdAt: DateTime(2026, 1, index),
  roles: [
    AdminStaffRole(
      roleId: 'r$index',
      roleCode: index.isEven ? 'manager' : 'cashier',
    ),
  ],
  permissions: index == 1 ? const ['orders.read'] : const <String>[],
);

Finder _label(String text) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == text);

void _setViewport(WidgetTester tester, double width, [double height = 900]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required List<AdminStaffMember> staff,
  String search = '',
  bool canManage = false,
  ValueChanged<AdminStaffMember>? onManage,
  ValueChanged<AdminStaffMember>? onEdit,
  VoidCallback? onInvite,
  VoidCallback? onShowInvitations,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: StaffPageBody(
            staff: staff,
            search: search,
            onSearchChanged: (_) {},
            canManagePermissions: canManage,
            onManage: onManage ?? (_) {},
            onEdit: onEdit ?? (_) {},
            onInvite: onInvite ?? () {},
            onShowInvitations: onShowInvitations ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('a narrow page fits and paginates the team', (tester) async {
    _setViewport(tester, 360, 800);
    await _pumpPage(
      tester,
      staff: [for (var index = 1; index <= 9; index++) _member(index)],
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.staffMetricTotal), findsOneWidget);
    expect(find.text(S.staffRowsLabel(1, 8, 9)), findsOneWidget);
    expect(find.text('Staff 1'), findsOneWidget);
    expect(find.text('Staff 9'), findsNothing);
  });

  testWidgets('the search shows only the matching member', (tester) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(
      tester,
      staff: [for (var index = 1; index <= 4; index++) _member(index)],
      search: 'Staff 2',
    );

    expect(_label('Staff 2'), findsOneWidget);
    expect(_label('Staff 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the status filter keeps the active members', (tester) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(
      tester,
      staff: [for (var index = 1; index <= 4; index++) _member(index)],
    );

    await tester.tap(find.byTooltip(S.staffFilter));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<StaffFilter>, S.staffFilterActive),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff 1'), findsOneWidget);
    expect(find.text('Staff 2'), findsNothing);
    expect(find.text('Staff 3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the permission action opens the dialog for one member', (
    tester,
  ) async {
    _setViewport(tester, 1280, 800);
    final opened = <String>[];
    await _pumpPage(
      tester,
      staff: [for (var index = 1; index <= 3; index++) _member(index)],
      canManage: true,
      onManage: (member) => opened.add(member.id),
    );

    expect(find.byTooltip(S.staffManagePermissions), findsWidgets);
    await tester.tap(find.byTooltip(S.staffManagePermissions).first);
    await tester.pump();

    expect(opened, ['s1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only staff show the view action', (tester) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(
      tester,
      staff: [for (var index = 1; index <= 3; index++) _member(index)],
    );

    expect(find.byTooltip(S.staffViewPermissions), findsWidgets);
    expect(find.byTooltip(S.staffManagePermissions), findsNothing);
    expect(find.byTooltip(S.editStaffTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the edit action opens the profile of one member', (
    tester,
  ) async {
    _setViewport(tester, 1280, 800);
    final edited = <String>[];
    await _pumpPage(
      tester,
      staff: [for (var index = 1; index <= 3; index++) _member(index)],
      canManage: true,
      onEdit: (member) => edited.add(member.id),
    );

    await tester.tap(find.byTooltip(S.editStaffTitle).first);
    await tester.pump();

    expect(edited, ['s1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header invites only a writer, and always lists invites', (
    tester,
  ) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(
      tester,
      staff: [for (var index = 1; index <= 3; index++) _member(index)],
    );

    expect(find.text(S.staffInvitations), findsOneWidget);
    expect(find.text(S.inviteStaff), findsNothing);

    var invited = 0;
    await _pumpPage(
      tester,
      staff: [for (var index = 1; index <= 3; index++) _member(index)],
      canManage: true,
      onInvite: () => invited++,
    );

    expect(find.text(S.inviteStaff), findsOneWidget);
    await tester.tap(find.text(S.inviteStaff));
    await tester.pump();

    expect(invited, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the invitations action opens the list the admin manages', (
    tester,
  ) async {
    _setViewport(tester, 1280, 800);
    var opened = 0;
    await _pumpPage(
      tester,
      staff: [for (var index = 1; index <= 3; index++) _member(index)],
      onShowInvitations: () => opened++,
    );

    await tester.tap(find.text(S.staffInvitations));
    await tester.pump();

    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty team shows the empty state', (tester) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(tester, staff: const []);

    expect(find.text(S.noStaffFound), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an Arabic right-to-left page fits', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 360, 800);
    await _pumpPage(
      tester,
      staff: [for (var index = 1; index <= 3; index++) _member(index)],
      canManage: true,
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.staffMetricTotal), findsOneWidget);
  });
}
