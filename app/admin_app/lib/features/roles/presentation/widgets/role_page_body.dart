import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_records.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';

/// The title and the list of the roles, the whole content of the page.
class RolePageBody extends StatelessWidget {
  const RolePageBody({
    super.key,
    required this.roles,
    required this.search,
    required this.canManage,
    required this.onManage,
  });

  final List<AdminRole> roles;
  final String search;
  final bool canManage;
  final ValueChanged<AdminRole> onManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.pageVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageTitle(S.rolesAndPermissions),
          const SizedBox(height: AppDimensions.lg),
          Expanded(
            child: RoleRecords(
              roles: roles,
              search: search,
              canManage: canManage,
              onManage: onManage,
            ),
          ),
        ],
      ),
    );
  }
}
