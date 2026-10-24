import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';

class StaffRecords extends StatelessWidget {
  const StaffRecords({
    super.key,
    required this.staff,
    this.search = '',
    this.canManagePermissions = false,
    this.onManage,
  });

  /// Every loaded staff member; the list filters them with [search].
  final List<AdminStaffMember> staff;

  /// The word the admin is looking for.
  final String search;

  final bool canManagePermissions;
  final ValueChanged<AdminStaffMember>? onManage;

  List<AdminStaffMember> get _filtered {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return staff;
    return staff
        .where(
          (member) =>
              (member.fullName ?? '').toLowerCase().contains(q) ||
              (member.email ?? '').toLowerCase().contains(q) ||
              member.roles.any((r) => r.roleCode.toLowerCase().contains(q)) ||
              member.permissions.any((p) => p.toLowerCase().contains(q)),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final staff = _filtered;
    if (staff.isEmpty) {
      return Center(
        child: Text(
          'No staff members',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
      );
    }

    return ListView.separated(
      itemCount: staff.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, index) {
        final member = staff[index];
        return _StaffCard(
          member: member,
          onTap: onManage == null ? null : () => onManage!(member),
        );
      },
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member, this.onTap});

  final AdminStaffMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
          border: Border.all(color: AppColor.recordBorder),
        ),
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (member.email != null && member.email!.isNotEmpty)
                        Text(
                          member.email!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColor.greyColor,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: member.status == 'active'
                        ? AppColor.primaryColor
                        : AppColor.errorColor,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
                  ),
                  child: Text(
                    member.status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColor.whiteColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Roles: ${member.roles.map((r) => r.roleCode).join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
