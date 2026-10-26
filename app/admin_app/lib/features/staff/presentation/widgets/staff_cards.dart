import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_avatar.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_format.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_table.dart';
import 'package:admin_app/shared/widgets/admin_labeled_value.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class StaffCards extends StatelessWidget {
  const StaffCards({
    super.key,
    required this.staff,
    required this.canManagePermissions,
    required this.onManage,
  });

  final List<AdminStaffMember> staff;
  final bool canManagePermissions;
  final ValueChanged<AdminStaffMember> onManage;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: staff.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final member = staff[index];
      return _StaffCard(
        member: member,
        canManagePermissions: canManagePermissions,
        onManage: () => onManage(member),
      );
    },
  );
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.member,
    required this.canManagePermissions,
    required this.onManage,
  });

  final AdminStaffMember member;
  final bool canManagePermissions;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final radius = BorderRadius.circular(12);
    final body = adminBodyColor(theme);
    final subtle = adminSubtleColor(theme);
    final status = StaffStatusView.of(member.status);
    final contact = staffContactLine(member);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onManage,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StaffAvatar(member: member, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staffDisplayName(member),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: body,
                            fontSize: AppFontSizes.size12,
                            fontWeight: AppFontWeights.bold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                        if (contact != null)
                          Text(
                            contact,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtle,
                              fontSize: AppFontSizes.size10,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AdminStatusBadge(label: status.label, color: status.color),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: AdminLabeledValue(
                      label: S.role,
                      child: Text(
                        staffRolesText(member),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: body,
                          fontSize: AppFontSizes.size11,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: AdminLabeledValue(
                      label: S.rolesTablePermissions,
                      child: Text(
                        staffPermissionsCount(member),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtle,
                          fontSize: AppFontSizes.size11,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AdminLabeledValue(
                      label: S.staffJoined,
                      child: Text(
                        staffJoined(member),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark
                              ? AppColor.darkTextSecondary
                              : AppColor.adminDate,
                          fontSize: AppFontSizes.size10_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ),
                  StaffPermissionAction(
                    canManage: canManagePermissions,
                    onPressed: onManage,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
