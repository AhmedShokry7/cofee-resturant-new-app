import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/auth/data/models/admin_session.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';
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
    expect(find.text(S.soonBadge), findsWidgets);

    await tester.tap(find.text(S.products));
    await tester.pump();
    expect(selected, 'products');
  });

  test('every database feature is listed as a destination', () {
    final ids = adminDestinations.map((destination) => destination.id).toSet();

    expect(
      ids,
      containsAll(<String>[
        'dashboard',
        'orders',
        'products',
        'categories',
        'bundles',
        'pricing',
        'carts',
        'inventory',
        'stockMovements',
        'payments',
        'savedCards',
        'customers',
        'addresses',
        'staff',
        'roles',
        'auditLog',
        'branches',
        'deliveryZones',
        'content',
        'appSettings',
        'coupons',
        'banners',
        'loyalty',
        'subscriptions',
        'reviews',
        'notifications',
        'favorites',
        'websites',
        'aiKnowledge',
      ]),
    );

    for (final destination in adminDestinations) {
      expect(destination.section, isNotNull, reason: destination.id);
      if (destination.id != 'dashboard') {
        expect(destination.tables, isNotEmpty, reason: destination.id);
        expect(destination.isImplemented, isFalse, reason: destination.id);
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
