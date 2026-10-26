import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_directory.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';

/// The header, the metrics and the directory of the roles page.
class RolePageBody extends StatelessWidget {
  const RolePageBody({
    super.key,
    required this.roles,
    required this.search,
    required this.onSearchChanged,
    required this.onManage,
    required this.canManage,
    this.errorMessage,
    this.onRefresh,
  });

  final List<AdminRole> roles;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminRole>? onManage;
  final bool canManage;
  final String? errorMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: S.rolesAndPermissions,
            subtitle: S.rolesDescription,
          ),
          if (errorMessage != null)
            AdminInlineError(message: errorMessage!, onRetry: onRefresh),
          const SizedBox(height: 7),
          RoleMetricsCards(roles: roles),
          const SizedBox(height: 16),
          Expanded(
            child: RoleDirectory(
              roles: roles,
              search: search,
              onSearchChanged: onSearchChanged,
              onManage: onManage,
              canManage: canManage,
            ),
          ),
        ],
      ),
    );
  }
}
