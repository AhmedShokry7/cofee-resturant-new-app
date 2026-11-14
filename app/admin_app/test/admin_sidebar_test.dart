import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/auth/admin_role_scope.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destinations.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar_item.dart';

AdminSession _session() => const AdminSession(
  staffId: 'u1',
  email: 'admin@example.com',
  fullName: 'Admin One',
  status: 'active',
  roles: [],
  permissionScopes: [],
  canManageAllBranches: true,
);

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('sidebar lists the destinations and reports the selection', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    String? selected;

    await tester.pumpWidget(
      _wrap(
        AdminSidebar(
          session: _session(),
          destinations: adminDestinations,
          selectedId: 'dashboard',
          onSelected: (id) => selected = id,
          onSignOut: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text(S.dashboard), findsOneWidget);
    expect(find.text(S.sectionManagement), findsOneWidget);

    await tester.tap(find.text(S.products));
    await tester.pump();
    expect(selected, 'products');
  });

  testWidgets('sidebar names the signed-in roles in the active language', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    // الشريط كان يولّد «Branch Manager» من الكود الإنجليزي نفسه، فيكسر عربيّة
    // الواجهة تحت الاسم؛ صار الاسم من خريطة الأدوار المشتركة.
    AppLocale.instance.debugSet(AppLanguage.arabic);
    addTearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

    await tester.pumpWidget(
      _wrap(
        AdminSidebar(
          session: const AdminSession(
            staffId: 'u2',
            email: 'manager@example.com',
            fullName: 'منى',
            status: 'active',
            roles: [
              AdminRoleScope(roleId: 'r1', roleCode: 'branch_manager'),
              AdminRoleScope(roleId: 'r2', roleCode: 'cashier'),
            ],
            permissionScopes: [],
            canManageAllBranches: false,
          ),
          destinations: adminDestinations,
          selectedId: 'dashboard',
          onSelected: (_) {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('${S.roleBranchManager}، ${S.roleCashier}'),
      findsOneWidget,
    );
    expect(find.text('Branch Manager, Cashier'), findsNothing);
  });

  testWidgets('sidebar shows the live work count on the operations rows', (
    tester,
  ) async {
    _setViewport(tester, 1280);

    await tester.pumpWidget(
      _wrap(
        AdminSidebar(
          session: _session(),
          destinations: adminDestinations,
          selectedId: 'dashboard',
          badges: const <String, int>{'orders': 12, 'kitchen': 140},
          onSelected: (_) {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text(localizeDigits('12')), findsOneWidget);
    expect(find.text(localizeDigits('99+')), findsOneWidget);
  });

  testWidgets('the notifications row carries its own unread count', (
    tester,
  ) async {
    _setViewport(tester, 1280);

    await tester.pumpWidget(
      _wrap(
        AdminSidebar(
          session: _session(),
          destinations: adminDestinations,
          selectedId: 'dashboard',
          badges: const <String, int>{'notifications': 7},
          onSelected: (_) {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pump();

    // The sidebar is a list, and the notifications row sits deep in it, so the
    // row has to be scrolled into view before it exists at all.
    final badge = find.text(localizeDigits('7'));
    await tester.scrollUntilVisible(badge, 200);
    await tester.pump();

    // The counters are keyed by the id of the destination: this proves the
    // number lands on the notifications row itself, not on any other row.
    final row = find.ancestor(
      of: badge,
      matching: find.byType(AdminSidebarItem),
    );
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.text(
          adminDestinations.firstWhere((d) => d.id == 'notifications').label,
        ),
      ),
      findsOneWidget,
    );
  });

  test('every database feature is listed as a destination', () {
    final ids = adminDestinations.map((destination) => destination.id).toSet();

    expect(
      ids,
      containsAll(<String>[
        'dashboard',
        'orders',
        'pos',
        'kitchen',
        'tables',
        'products',
        'categories',
        'bundles',
        'carts',
        'inventory',
        'stockMovements',
        'payments',
        'customers',
        'staff',
        'roles',
        'auditLog',
        'branches',
        'content',
        'appSettings',
        'coupons',
        'banners',
        'loyalty',
        'subscriptions',
        'reviews',
        'notifications',
        'websites',
        'aiKnowledge',
        'visualEditor',
      ]),
    );
    expect(ids, isNot(contains('deliveryZones')));
    expect(ids, isNot(contains('pricing')));

    for (final destination in adminDestinations) {
      expect(destination.section, isNotNull, reason: destination.id);
      if (destination.id != 'dashboard' &&
          destination.id != 'orders' &&
          destination.id != 'visualEditor' {
        expect(destination.tables, isNotEmpty, reason: destination.id);
      }
    }
  });

  testWidgets('sidebar fits a narrow viewport', (tester) async {
    _setViewport(tester, 360);

    await tester.pumpWidget(
      _wrap(
        AdminSidebar(
          session: _session(),
          destinations: adminDestinations,
          selectedId: 'orders',
          onSelected: (_) {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text(S.orders), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
