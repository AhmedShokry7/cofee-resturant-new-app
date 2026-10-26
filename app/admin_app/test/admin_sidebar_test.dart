import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destinations.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar.dart';

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
        'customerPreview',
      ]),
    );
    expect(ids, isNot(contains('deliveryZones')));
    expect(ids, isNot(contains('pricing')));

    for (final destination in adminDestinations) {
      expect(destination.section, isNotNull, reason: destination.id);
      if (destination.id != 'dashboard' &&
          destination.id != 'orders' &&
          destination.id != 'customerPreview') {
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
