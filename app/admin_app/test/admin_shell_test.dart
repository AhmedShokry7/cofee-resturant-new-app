import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/auth/admin_permission_scope.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destinations.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/shell/presentation/models/admin_shell_layout_data.dart';
import 'package:admin_app/features/catalog/presentation/pages/product_page.dart';
import 'package:admin_app/features/shell/presentation/views/admin_shell.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_app_bar.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_desktop_layout.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_mobile_layout.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar_item.dart';

/// An admin that may open the dashboard, the landing area of the shell.
AdminSession _session() => const AdminSession(
  staffId: 'u1',
  email: 'admin@example.com',
  fullName: 'Admin One',
  status: 'active',
  roles: [],
  permissionScopes: [
    AdminPermissionScope(permissions: ['orders.read']),
  ],
  canManageAllBranches: true,
);

/// A staff member with no permission at all, so no area is reachable.
AdminSession _sessionWithoutAccess() => const AdminSession(
  staffId: 'u1',
  email: 'admin@example.com',
  fullName: 'Admin One',
  status: 'active',
  roles: [],
  permissionScopes: [],
  canManageAllBranches: true,
);

/// A staff member that may write the products.
AdminSession _sessionWithProducts() => const AdminSession(
  staffId: 'u1',
  email: 'admin@example.com',
  fullName: 'Admin One',
  status: 'active',
  roles: [],
  permissionScopes: [
    AdminPermissionScope(permissions: ['orders.read', 'catalog.product.write']),
  ],
  canManageAllBranches: true,
);

/// A staff member that may run the counter.
AdminSession _sessionWithPos() => const AdminSession(
  staffId: 'u1',
  email: 'admin@example.com',
  fullName: 'Admin One',
  status: 'active',
  roles: [],
  permissionScopes: [
    AdminPermissionScope(permissions: ['orders.read', 'pos.manage']),
  ],
  canManageAllBranches: true,
);

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The sidebar entry labelled [label] in the language the panel uses now.
Finder _sidebarItem(String label) => find.descendant(
  of: find.byType(AdminSidebar),
  matching: find.widgetWithText(AdminSidebarItem, label),
);

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

  testWidgets('the sidebar follows the language of the panel', (tester) async {
    _setViewport(tester, 1280);
    AppLocale.instance.debugSet(AppLanguage.english);
    addTearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

    await tester.pumpWidget(MaterialApp(home: AdminShell(session: _session())));
    await tester.pump();

    // The sidebar carries the text of the panel.
    expect(find.byType(AdminSidebar), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Sign out'), findsOneWidget);

    // The panel is switched to Arabic while the app runs.
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await tester.pump();

    // The sidebar shows the Arabic text, without a restart.
    expect(find.text(S.dashboard), findsWidgets);
    expect(find.text(S.signOut), findsWidgets);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('the sidebar follows the language back to English', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    AppLocale.instance.debugSet(AppLanguage.arabic);
    addTearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

    await tester.pumpWidget(MaterialApp(home: AdminShell(session: _session())));
    await tester.pump();

    expect(find.text(S.dashboard), findsWidgets);
    expect(find.text('Dashboard'), findsNothing);

    AppLocale.instance.debugSet(AppLanguage.english);
    await tester.pump();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets(
    'the selected item and the menu state survive a language switch',
    (tester) async {
      _setViewport(tester, 1280);
      AppLocale.instance.debugSet(AppLanguage.english);
      addTearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

      await tester.pumpWidget(
        MaterialApp(home: AdminShell(session: _sessionWithProducts())),
      );
      await tester.pump();

      // The item is picked by its label: which items the sidebar holds at all
      // depends on the permissions of the account.
      await tester.tap(_sidebarItem('Products'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<AdminSidebarItem>(_sidebarItem('Products')).isSelected,
        isTrue,
      );

      AppLocale.instance.debugSet(AppLanguage.arabic);
      await tester.pump();

      // The same item is still the one that is selected.
      expect(
        tester.widget<AdminSidebarItem>(_sidebarItem(S.products)).isSelected,
        isTrue,
      );
      // And the panel still shows the products page.
      expect(find.byType(ProductPage), findsOneWidget);
    },
  );

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

  testWidgets('the counter trades the sidebar for a drawer on smaller desks', (
    tester,
  ) async {
    _setViewport(tester, 1280);

    await tester.pumpWidget(
      MaterialApp(home: AdminShell(session: _sessionWithPos())),
    );
    await tester.pump();

    // The dashboard still keeps the permanent sidebar at this width.
    expect(find.byType(AdminSidebar), findsOneWidget);
    expect(find.byTooltip(S.menu), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.text(S.pos),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The counter needs the whole width for the current order panel.
    expect(find.byType(AdminSidebar), findsNothing);
    expect(find.byTooltip(S.menu), findsOneWidget);

    await tester.tap(find.byTooltip(S.menu));
    await tester.pumpAndSettle();
    expect(find.byType(AdminSidebar), findsOneWidget);
  });

  testWidgets('an account with no permission keeps the frame and signs out', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    AppLocale.instance.debugSet(AppLanguage.english);
    addTearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

    await tester.pumpWidget(
      MaterialApp(home: AdminShell(session: _sessionWithoutAccess())),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // No destination is listed, yet the shell still paints its frame.
    expect(find.byType(AdminSidebar), findsOneWidget);
    expect(find.byType(AdminSidebarItem), findsNothing);
    expect(find.text(S.noAccessTitle), findsOneWidget);
    expect(find.text(S.noAccessMessage), findsOneWidget);
    // A search box that filters nothing is not offered.
    expect(find.byType(TextField), findsNothing);
    // Sign out stays reachable, otherwise the account is locked in a dead page.
    expect(find.text('Sign out'), findsOneWidget);
  });
}
