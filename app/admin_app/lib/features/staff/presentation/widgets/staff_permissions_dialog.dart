import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_cubit.dart';
import 'package:admin_app/shared/widgets/admin_permissions_dialog.dart';

/// Loads the permission catalogue and opens the permission editor of one
/// staff member.
Future<void> showStaffPermissionsDialog({
  required BuildContext context,
  required AdminStaffCubit cubit,
  required AdminStaffMember member,
  required bool canManage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  List<Map<String, dynamic>> allPermissions;
  try {
    allPermissions = await cubit.loadPermissions();
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(S.permissionsLoadFailed)));
    return;
  }
  if (!context.mounted) return;

  final email = member.email?.trim() ?? '';
  await showAdminPermissionsDialog(
    context: context,
    title: S.permissionsFor(member.displayName()),
    subtitle: email.isEmpty ? S.permissionsDialogSubtitle : email,
    granted: member.permissions.toSet(),
    catalog: allPermissions,
    canManage: canManage,
    emptyMessage: canManage ? null : S.roleNoPermissions,
    onToggle: (code, granted) =>
        cubit.setStaffPermission(member.id, code, granted),
  );
  if (canManage) await cubit.load();
}
