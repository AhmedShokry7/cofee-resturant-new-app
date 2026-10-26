import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/models/role_filter.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_format.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_page_body.dart';

AdminRole _role(int index) => AdminRole(
  id: 'r$index',
  code: index.isEven ? 'manager' : 'shift_leader',
  nameAr: index.isEven ? 'مدير عام' : 'قائد وردية',
  nameEn: index.isEven ? 'Manager' : 'Shift leader',
  isSystem: index.isEven,
  permissions: index.isEven
      ? const ['orders.read', 'payments.read']
      : const <String>[],
);

void _setViewport(WidgetTester tester, double width, [double height = 900]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required List<AdminRole> roles,
  String search = '',
  bool canManage = false,
  ValueChanged<AdminRole>? onManage,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: RolePageBody(
            roles: roles,
            search: search,
            onSearchChanged: (_) {},
            onManage: onManage ?? (_) {},
            canManage: canManage,
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

  testWidgets('a narrow page fits and paginates the roles', (tester) async {
    _setViewport(tester, 360, 800);
    await _pumpPage(
      tester,
      roles: [for (var index = 1; index <= 9; index++) _role(index)],
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.rolesMetricTotal), findsOneWidget);
    expect(find.text(S.rolesRowsLabel(1, 8, 9)), findsOneWidget);
    expect(find.text('Manager'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the type filter keeps the system roles', (tester) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(
      tester,
      roles: [for (var index = 1; index <= 4; index++) _role(index)],
    );

    await tester.tap(find.byTooltip(S.rolesFilter));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<RoleFilter>, S.rolesFilterSystem),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manager'), findsWidgets);
    expect(find.text('Shift leader'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a manager can open one role permissions', (tester) async {
    _setViewport(tester, 1280, 800);
    final opened = <String>[];
    await _pumpPage(
      tester,
      roles: [for (var index = 1; index <= 3; index++) _role(index)],
      canManage: true,
      onManage: (role) => opened.add(role.id),
    );

    expect(find.byTooltip(S.roleManagePermissions), findsWidgets);
    await tester.tap(find.byTooltip(S.roleManagePermissions).first);
    await tester.pump();

    expect(opened, ['r1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a read-only role list opens the permissions', (tester) async {
    _setViewport(tester, 1280, 800);
    final opened = <String>[];
    await _pumpPage(
      tester,
      roles: [for (var index = 1; index <= 3; index++) _role(index)],
      onManage: (role) => opened.add(role.id),
    );

    expect(find.byTooltip(S.roleViewPermissions), findsWidgets);
    expect(find.byTooltip(S.roleManagePermissions), findsNothing);
    expect(find.text(rolePermissionPreview(_role(1))), findsWidgets);

    await tester.tap(find.byTooltip(S.roleViewPermissions).first);
    await tester.pump();

    expect(opened, ['r1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty role list shows the empty state', (tester) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(tester, roles: const []);

    expect(find.text(S.noRolesFound), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an Arabic right-to-left page fits', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 360, 800);
    await _pumpPage(
      tester,
      roles: [for (var index = 1; index <= 3; index++) _role(index)],
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.rolesMetricTotal), findsOneWidget);
    expect(find.text('مدير عام'), findsWidgets);
  });
}
