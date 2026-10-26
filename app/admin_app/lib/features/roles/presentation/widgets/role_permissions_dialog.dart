import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/manager/admin_role_cubit.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_format.dart';
import 'package:admin_app/shared/widgets/admin_permissions_dialog.dart';

/// Loads the permission catalogue and opens the dialog that grants it to a
/// role, one permission at a time.
Future<void> showRolePermissionsDialog({
  required BuildContext context,
  required AdminRoleCubit cubit,
  required AdminRole role,
  required bool canManage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  List<Map<String, dynamic>> allPermissions;
  if (canManage) {
    try {
      allPermissions = await cubit.loadPermissions();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(S.permissionsLoadFailed)));
      return;
    }
  } else {
    allPermissions = rolePermissionEntries(role);
  }
  if (!context.mounted) return;

  await showAdminPermissionsDialog(
    context: context,
    title: S.permissionsFor(roleDisplayName(role)),
    subtitle: role.code,
    granted: role.permissions.toSet(),
    catalog: allPermissions,
    canManage: canManage,
    emptyMessage: canManage ? null : S.roleNoPermissions,
    onToggle: (code, granted) =>
        cubit.setRolePermission(role.id, code, granted),
  );
  if (canManage) await cubit.load();
}
