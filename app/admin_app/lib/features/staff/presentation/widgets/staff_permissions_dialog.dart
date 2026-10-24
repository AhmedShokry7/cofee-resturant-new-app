import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_cubit.dart';

/// The English name of every permission code of the dashboard.
const Map<String, String> kPermissionNameEn = <String, String>{
  'admin.role.read': 'View roles',
  'admin.role.write': 'Manage roles',
  'admin.staff.read': 'View staff',
  'admin.staff.write': 'Manage staff',
  'audit.read': 'Read audit log',
  'catalog.category.write': 'Manage categories',
  'catalog.product.write': 'Manage products',
  'customers.read': 'View customers',
  'customers.write': 'Manage customers',
  'inventory.adjust': 'Adjust stock',
  'inventory.read': 'View stock',
  'loyalty.read': 'View loyalty',
  'loyalty.write': 'Manage loyalty',
  'notifications.read': 'View notifications',
  'orders.cancel': 'Cancel orders',
  'orders.read': 'View orders',
  'orders.status.update': 'Update order status',
  'payments.read': 'View payments',
  'reviews.moderate': 'Moderate reviews',
  'settings.write': 'Manage settings',
  'subscriptions.consume': 'Consume subscription cups',
  'subscriptions.manage': 'Manage subscriptions',
};

/// The Arabic name of every permission code of the dashboard.
const Map<String, String> kPermissionNameAr = <String, String>{
  'admin.role.read': 'ط¹ط±ط¶ ط§ظ„ط£ط¯ظˆط§ط±',
  'admin.role.write': 'ط¥ط¯ط§ط±ط© ط§ظ„ط£ط¯ظˆط§ط±',
  'admin.staff.read': 'ط¹ط±ط¶ ط§ظ„ظ…ظˆط¸ظپظٹظ†',
  'admin.staff.write': 'ط¥ط¯ط§ط±ط© ط§ظ„ظ…ظˆط¸ظپظٹظ†',
  'audit.read': 'ظ‚ط±ط§ط،ط© ط³ط¬ظ„ ط§ظ„طھط¯ظ‚ظٹظ‚',
  'catalog.category.write': 'ط¥ط¯ط§ط±ط© ط§ظ„ظپط¦ط§طھ',
  'catalog.product.write': 'ط¥ط¯ط§ط±ط© ط§ظ„ظ…ظ†طھط¬ط§طھ',
  'customers.read': 'ط¹ط±ط¶ ط§ظ„ط¹ظ…ظ„ط§ط،',
  'customers.write': 'ط¥ط¯ط§ط±ط© ط§ظ„ط¹ظ…ظ„ط§ط،',
  'inventory.adjust': 'طھط¹ط¯ظٹظ„ ط§ظ„ظ…ط®ط²ظˆظ†',
  'inventory.read': 'ط¹ط±ط¶ ط§ظ„ظ…ط®ط²ظˆظ†',
  'loyalty.read': 'ط¹ط±ط¶ ط§ظ„ظˆظ„ط§ط،',
  'loyalty.write': 'ط¥ط¯ط§ط±ط© ط§ظ„ظˆظ„ط§ط،',
  'notifications.read': 'ط¹ط±ط¶ ط§ظ„ط¥ط´ط¹ط§ط±ط§طھ',
  'orders.cancel': 'ط¥ظ„ط؛ط§ط، ط§ظ„ط·ظ„ط¨ط§طھ',
  'orders.read': 'ط¹ط±ط¶ ط§ظ„ط·ظ„ط¨ط§طھ',
  'orders.status.update': 'طھط­ط¯ظٹط« ط­ط§ظ„ط© ط§ظ„ط·ظ„ط¨',
  'payments.read': 'ط¹ط±ط¶ ط§ظ„ظ…ط¯ظپظˆط¹ط§طھ',
  'reviews.moderate': 'ظ…ط±ط§ط¬ط¹ط© ط§ظ„طھظ‚ظٹظٹظ…ط§طھ',
  'settings.write': 'ط¥ط¯ط§ط±ط© ط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ',
  'subscriptions.consume': 'ط§ط³طھظ‡ظ„ط§ظƒ ط£ظƒظˆط§ط¨ ط§ظ„ط§ط´طھط±ط§ظƒ',
  'subscriptions.manage': 'ط¥ط¯ط§ط±ط© ط§ظ„ط§ط´طھط±ط§ظƒط§طھ',
};

/// The English description of every permission code of the dashboard.
const Map<String, String> kPermissionDescEn = <String, String>{
  'admin.role.read': 'View roles and their permissions.',
  'admin.role.write': 'Create, edit and delete roles.',
  'admin.staff.read': 'View staff members.',
  'admin.staff.write': 'Add, edit and remove staff.',
  'audit.read': 'View the audit log.',
  'catalog.category.write': 'Create, edit and delete categories.',
  'catalog.product.write': 'Create, edit and delete products.',
  'customers.read': 'View customer profiles and history.',
  'customers.write': 'Edit customer status and notes.',
  'inventory.adjust': 'Adjust stock quantities.',
  'inventory.read': 'View inventory levels.',
  'loyalty.read': 'View loyalty accounts and rules.',
  'loyalty.write': 'Manage loyalty rules and rewards.',
  'notifications.read': 'View all notifications.',
  'orders.cancel': 'Cancel orders.',
  'orders.read': 'View orders.',
  'orders.status.update': 'Change order status.',
  'payments.read': 'View payment transactions.',
  'reviews.moderate': 'Approve or reject reviews.',
  'settings.write': 'Manage app settings.',
  'subscriptions.consume': 'Redeem subscription cups.',
  'subscriptions.manage': 'Manage subscription plans.',
};

/// The Arabic description of every permission code of the dashboard.
const Map<String, String> kPermissionDescAr = <String, String>{
  'admin.role.read': 'ط¹ط±ط¶ ط§ظ„ط£ط¯ظˆط§ط± ظˆطµظ„ط§ط­ظٹط§طھظ‡ط§.',
  'admin.role.write': 'ط¥ظ†ط´ط§ط، ظˆطھط¹ط¯ظٹظ„ ظˆط­ط°ظپ ط§ظ„ط£ط¯ظˆط§ط±.',
  'admin.staff.read': 'ط¹ط±ط¶ ط§ظ„ظ…ظˆط¸ظپظٹظ†.',
  'admin.staff.write': 'ط¥ط¶ط§ظپط© ظˆطھط¹ط¯ظٹظ„ ظˆط¥ط²ط§ظ„ط© ط§ظ„ظ…ظˆط¸ظپظٹظ†.',
  'audit.read': 'ط¹ط±ط¶ ط³ط¬ظ„ ط§ظ„طھط¯ظ‚ظٹظ‚.',
  'catalog.category.write': 'ط¥ظ†ط´ط§ط، ظˆطھط¹ط¯ظٹظ„ ظˆط­ط°ظپ ط§ظ„ظپط¦ط§طھ.',
  'catalog.product.write': 'ط¥ظ†ط´ط§ط، ظˆطھط¹ط¯ظٹظ„ ظˆط­ط°ظپ ط§ظ„ظ…ظ†طھط¬ط§طھ.',
  'customers.read': 'ط¹ط±ط¶ ظ…ظ„ظپط§طھ ط§ظ„ط¹ظ…ظ„ط§ط، ظˆطھط§ط±ظٹط®ظ‡ظ….',
  'customers.write': 'طھط¹ط¯ظٹظ„ ط­ط§ظ„ط© ط§ظ„ط¹ظ…ظٹظ„ ظˆظ…ظ„ط§ط­ط¸ط§طھظ‡.',
  'inventory.adjust': 'طھط¹ط¯ظٹظ„ ظƒظ…ظٹط§طھ ط§ظ„ظ…ط®ط²ظˆظ†.',
  'inventory.read': 'ط¹ط±ط¶ ظ…ط³طھظˆظٹط§طھ ط§ظ„ظ…ط®ط²ظˆظ†.',
  'loyalty.read': 'ط¹ط±ط¶ ط­ط³ط§ط¨ط§طھ ظˆظ‚ظˆط§ط¹ط¯ ط§ظ„ظˆظ„ط§ط،.',
  'loyalty.write': 'ط¥ط¯ط§ط±ط© ظ‚ظˆط§ط¹ط¯ ظˆظ…ظƒط§ظپط¢طھ ط§ظ„ظˆظ„ط§ط،.',
  'notifications.read': 'ط¹ط±ط¶ ط¬ظ…ظٹط¹ ط§ظ„ط¥ط´ط¹ط§ط±ط§طھ.',
  'orders.cancel': 'ط¥ظ„ط؛ط§ط، ط§ظ„ط·ظ„ط¨ط§طھ.',
  'orders.read': 'ط¹ط±ط¶ ط§ظ„ط·ظ„ط¨ط§طھ.',
  'orders.status.update': 'طھط؛ظٹظٹط± ط­ط§ظ„ط© ط§ظ„ط·ظ„ط¨.',
  'payments.read': 'ط¹ط±ط¶ ظ…ط¹ط§ظ…ظ„ط§طھ ط§ظ„ط¯ظپط¹.',
  'reviews.moderate':
      'ط§ظ„ظ…ظˆط§ظپظ‚ط© ط¹ظ„ظ‰ ط§ظ„طھظ‚ظٹظٹظ…ط§طھ ط£ظˆ ط±ظپط¶ظ‡ط§.',
  'settings.write': 'ط¥ط¯ط§ط±ط© ط¥ط¹ط¯ط§ط¯ط§طھ ط§ظ„طھط·ط¨ظٹظ‚.',
  'subscriptions.consume': 'ط§ط³طھظ‡ظ„ط§ظƒ ط£ظƒظˆط§ط¨ ط§ظ„ط§ط´طھط±ط§ظƒ.',
  'subscriptions.manage': 'ط¥ط¯ط§ط±ط© ط§ظ„ط§ط´طھط±ط§ظƒط§طھ.',
};

/// The name of a permission in the language of the panel.
String permissionName(String code, {required bool isArabic}) => isArabic
    ? (kPermissionNameAr[code] ?? code)
    : (kPermissionNameEn[code] ?? code);

/// The description of a permission in the language of the panel.
String permissionDescription(String code, {required bool isArabic}) => isArabic
    ? (kPermissionDescAr[code] ?? code)
    : (kPermissionDescEn[code] ?? code);

/// Loads the permission catalogue and opens the dialog that grants it to a
/// staff member, one permission at a time.
Future<void> showStaffPermissionsDialog({
  required BuildContext context,
  required AdminStaffCubit cubit,
  required AdminStaffMember member,
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
    builder: (context) => StaffPermissionsDialog(
      member: member,
      permissions: allPermissions,
      onToggle: (code, granted) =>
          cubit.setStaffPermission(member.id, code, granted),
    ),
  );
}

/// Every permission of the dashboard, checked for one staff member.
class StaffPermissionsDialog extends StatefulWidget {
  const StaffPermissionsDialog({
    super.key,
    required this.member,
    required this.permissions,
    required this.onToggle,
  });

  final AdminStaffMember member;

  /// The permission catalogue, read once from the database.
  final List<Map<String, dynamic>> permissions;

  final Future<void> Function(String code, bool granted) onToggle;

  @override
  State<StaffPermissionsDialog> createState() => _StaffPermissionsDialogState();
}

class _StaffPermissionsDialogState extends State<StaffPermissionsDialog> {
  late final Set<String> _granted;

  @override
  void initState() {
    super.initState();
    _granted = Set<String>.from(widget.member.permissions);
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
    final isAr = AppLocale.instance.isArabic;
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
              title: Text(permissionName(code, isArabic: isAr)),
              subtitle: Text(permissionDescription(code, isArabic: isAr)),
              onChanged: (value) => _toggle(code, value == true),
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
