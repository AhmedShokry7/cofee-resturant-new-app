import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
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
    required this.onEdit,
  });

  final List<AdminStaffMember> staff;
  final bool canManagePermissions;
  final ValueChanged<AdminStaffMember> onManage;
  final ValueChanged<AdminStaffMember> onEdit;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: staff.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px8),
    itemBuilder: (context, index) {
      final member = staff[index];
      return _StaffCard(
        member: member,
        canManagePermissions: canManagePermissions,
        onManage: () => onManage(member),
        onEdit: () => onEdit(member),
      );
    },
  );
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.member,
    required this.canManagePermissions,
    required this.onManage,
    required this.onEdit,
  });

  final AdminStaffMember member;
  final bool canManagePermissions;
  final VoidCallback onManage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final radius = BorderRadius.circular(AppRadius.lg);
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
          padding: const EdgeInsets.all(AppSpacing.md),
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
                  const SizedBox(width: AppSizes.px10),
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
                  const SizedBox(width: AppSizes.px8),
                  AdminStatusBadge(label: status.label, color: status.color),
                ],
              ),
              const SizedBox(height: AppSizes.px10),
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
                  const SizedBox(width: AppSizes.px8),
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
              const SizedBox(height: AppSizes.px8),
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
                  if (canManagePermissions) ...[
                    StaffEditAction(onPressed: onEdit),
                    const SizedBox(width: AppSizes.px4),
                  ],
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
