import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/shell/presentation/models/admin_shell_layout_data.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_app_bar.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar.dart';

/// The compact screen shell: a drawer that holds the same navigation panel.
class AdminMobileLayout extends StatelessWidget {
  const AdminMobileLayout({
    super.key,
    required this.data,
    required this.content,
  });

  final AdminShellLayoutData data;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdminAppBar(
        title: data.title,
        searchHint: data.searchHint,
        searchController: data.searchController,
        searchTextController: data.searchTextController,
        isCompact: true,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: S.menu,
            icon: const Icon(HugeIcons.strokeRoundedMenu01),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: AdminSidebar(
          session: data.session,
          destinations: data.destinations,
          selectedId: data.selectedId,
          onSelected: (id) {
            data.onSelected(id);
            Navigator.of(context).pop();
          },
          onSignOut: () {
            Navigator.of(context).pop();
            data.onSignOut();
          },
        ),
      ),
      body: content,
    );
  }
}
