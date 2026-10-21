import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/shell/presentation/models/admin_shell_layout_data.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_app_bar.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar.dart';

/// The wide screen shell: a permanent navigation panel beside the content.
class AdminDesktopLayout extends StatelessWidget {
  const AdminDesktopLayout({
    super.key,
    required this.data,
    required this.content,
  });

  final AdminShellLayoutData data;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(
            session: data.session,
            destinations: data.destinations,
            selectedId: data.selectedId,
            onSelected: data.onSelected,
            onSignOut: data.onSignOut,
          ),
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
              body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppDimensions.contentMaxWidth,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
