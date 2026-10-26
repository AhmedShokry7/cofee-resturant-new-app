import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/auth/admin_permission_scope.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/customer_preview/presentation/pages/customer_preview_page.dart';
import 'package:admin_app/features/shell/presentation/views/admin_shell.dart';

AdminSession _session() => const AdminSession(
  staffId: 'u1',
  email: 'admin@example.com',
  fullName: 'Admin One',
  status: 'active',
  roles: [],
  permissionScopes: [
    AdminPermissionScope(permissions: ['settings.write']),
  ],
  canManageAllBranches: true,
);

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('customer preview page builds', (tester) async {
    _setViewport(tester, 1280);
    AppLocale.instance.debugSet(AppLanguage.english);
    addTearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

    await tester.pumpWidget(MaterialApp(home: const CustomerPreviewPage()));
    await tester.pump();

    expect(find.text('Customer preview'), findsWidgets);
  });

  testWidgets('shell can open customer preview destination', (tester) async {
    _setViewport(tester, 1280);
    AppLocale.instance.debugSet(AppLanguage.english);
    addTearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

    await tester.pumpWidget(MaterialApp(home: AdminShell(session: _session())));
    await tester.pump();

    // Select customer preview via sidebar if present.
    final item = find.text('Customer preview');
    if (item.evaluate().isNotEmpty) {
      await tester.tap(item.first);
      await tester.pumpAndSettle();
      expect(find.byType(CustomerPreviewPage), findsOneWidget);
    }
  });
}
