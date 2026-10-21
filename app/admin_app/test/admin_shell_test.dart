import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/auth/data/models/admin_session.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/features/shell/presentation/models/admin_shell_layout_data.dart';
import 'package:admin_app/features/shell/presentation/views/admin_shell.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_app_bar.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_desktop_layout.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_mobile_layout.dart';
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

AdminShellLayoutData _data({
  required AdminSearchController searchController,
  required TextEditingController searchTextController,
  ValueChanged<String>? onSelected,
  VoidCallback? onSignOut,
}) {
  return AdminShellLayoutData(
    session: _session(),
    destinations: adminDestinations,
    selectedId: 'dashboard',
    onSelected: onSelected ?? (_) {},
    onSignOut: onSignOut ?? () {},
    searchController: searchController,
    searchTextController: searchTextController,
    title: S.dashboard,
    searchHint: S.searchDashboardHint,
  );
}

void main() {
  testWidgets('desktop layout shows the sidebar and the wide app bar', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    final searchController = AdminSearchController();
    final searchTextController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDesktopLayout(
          data: _data(
            searchController: searchController,
            searchTextController: searchTextController,
          ),
          content: const Text('content'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AdminSidebar), findsOneWidget);
    expect(find.byType(AdminAppBar), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    expect(find.byTooltip(S.menu), findsNothing);

    searchController.dispose();
    searchTextController.dispose();
  });

  testWidgets('mobile layout hides the sidebar behind a menu button', (
    tester,
  ) async {
    _setViewport(tester, 480);
    final searchController = AdminSearchController();
    final searchTextController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminMobileLayout(
          data: _data(
            searchController: searchController,
            searchTextController: searchTextController,
          ),
          content: const Text('content'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AdminSidebar), findsNothing);
    expect(find.byTooltip(S.menu), findsOneWidget);
    expect(find.text('content'), findsOneWidget);

    await tester.tap(find.byTooltip(S.menu));
    await tester.pumpAndSettle();
    expect(find.byType(AdminSidebar), findsOneWidget);

    searchController.dispose();
    searchTextController.dispose();
  });

  testWidgets('shell switches layout with the viewport width', (tester) async {
    _setViewport(tester, 1280);

    await tester.pumpWidget(MaterialApp(home: AdminShell(session: _session())));
    await tester.pump();

    expect(find.byType(AdminDesktopLayout), findsOneWidget);
    expect(find.byType(AdminMobileLayout), findsNothing);

    _setViewport(tester, 480);
    await tester.pumpWidget(MaterialApp(home: AdminShell(session: _session())));
    await tester.pumpAndSettle();

    expect(find.byType(AdminMobileLayout), findsOneWidget);
    expect(find.byType(AdminDesktopLayout), findsNothing);
  });
}
