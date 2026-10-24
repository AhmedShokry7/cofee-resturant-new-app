import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/manager/admin_role_cubit.dart';

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
  try {
    allPermissions = await cubit.loadPermissions();
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('$error')));
    return;
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) => RolePermissionsDialog(
      role: role,
      canManage: canManage,
      permissions: allPermissions,
      onToggle: (code, granted) =>
          cubit.setRolePermission(role.id, code, granted),
    ),
  );
}

/// Every permission of the dashboard, checked for one role.
class RolePermissionsDialog extends StatefulWidget {
  const RolePermissionsDialog({
    super.key,
    required this.role,
    required this.canManage,
    required this.permissions,
    required this.onToggle,
  });

  final AdminRole role;

  /// False for a staff that may only read the rights of the role.
  final bool canManage;

  /// The permission catalogue, read once from the database.
  final List<Map<String, dynamic>> permissions;

  final Future<void> Function(String code, bool granted) onToggle;

  @override
  State<RolePermissionsDialog> createState() => _RolePermissionsDialogState();
}

class _RolePermissionsDialogState extends State<RolePermissionsDialog> {
  late final Set<String> _granted;

  @override
  void initState() {
    super.initState();
    _granted = Set<String>.from(widget.role.permissions);
  }

  Future<void> _toggle(String code, bool value) async {
    try {
      await widget.onToggle(code, value);
      if (!mounted) return;
      setState(() {
        if (value) {
          _granted.add(code);
        } else {
          _granted.remove(code);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(': '),
      content: SizedBox(
        width: 520,
        height: 480,
        child: ListView.separated(
          itemCount: widget.permissions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final p = widget.permissions[index];
            final code = '${p['code']}';
            return CheckboxListTile(
              value: _granted.contains(code),
              title: Text('${p['name_en'] ?? p['name_ar'] ?? code}'),
              subtitle: Text(code),
              onChanged: widget.canManage
                  ? (value) => _toggle(code, value == true)
                  : null,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.close),
        ),
      ],
    );
  }
}
