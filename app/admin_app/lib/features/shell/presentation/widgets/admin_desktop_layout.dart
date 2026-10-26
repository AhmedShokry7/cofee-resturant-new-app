import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/shell/presentation/models/admin_shell_layout_data.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_app_bar.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar.dart';

/// The wide screen shell: a permanent navigation panel beside the content.
///
/// A workspace page that needs the whole width asks for a collapsed sidebar;
/// the panel moves into a drawer then, so navigation stays one tap away.
class AdminDesktopLayout extends StatelessWidget {
  const AdminDesktopLayout({
    super.key,
    required this.data,
    required this.content,
    this.collapseSidebar = false,
  });

  final AdminShellLayoutData data;
  final Widget content;
  final bool collapseSidebar;

  @override
  Widget build(BuildContext context) {
    final sidebar = AdminSidebar(
      session: data.session,
      destinations: data.destinations,
      selectedId: data.selectedId,
      badges: data.badges,
      onSelected: collapseSidebar
          ? (id) {
              Navigator.of(context).pop();
              data.onSelected(id);
            }
          : data.onSelected,
      onSignOut: collapseSidebar
          ? () {
              Navigator.of(context).pop();
              data.onSignOut();
            }
          : data.onSignOut,
    );

    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimensions.contentMaxWidth,
        ),
        child: content,
      ),
    );

    if (collapseSidebar) {
      // The drawer belongs to the same Scaffold as the menu button, otherwise
      // the button has nothing to open.
      return Scaffold(
        drawer: Drawer(child: sidebar),
        appBar: AdminAppBar(
          title: data.title,
          searchHint: data.searchHint,
          searchController: data.searchController,
          searchTextController: data.searchTextController,
          isCompact: false,
          leading: const _SidebarMenuButton(),
        ),
        body: body,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          const VerticalDivider(width: 1),
          Expanded(
            child: Scaffold(
              appBar: AdminAppBar(
                title: data.title,
                searchHint: data.searchHint,
                searchController: data.searchController,
                searchTextController: data.searchTextController,
                isCompact: false,
              ),
              body: body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the navigation drawer of a workspace page.
class _SidebarMenuButton extends StatelessWidget {
  const _SidebarMenuButton();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => IconButton(
        tooltip: S.menu,
        icon: const Icon(HugeIcons.strokeRoundedMenu01),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    );
  }
}
