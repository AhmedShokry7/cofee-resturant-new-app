import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_avatar.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class StaffTable extends StatelessWidget {
  const StaffTable({
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

  static const _actionWidth = 76.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, 980), 1600)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _Header(),
                for (final member in staff)
                  _Row(
                    member: member,
                    canManagePermissions: canManagePermissions,
                    onManage: () => onManage(member),
                    onEdit: () => onEdit(member),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminTableBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: _cell(S.staffMemberColumn, theme)),
          Expanded(flex: 3, child: _cell(S.role, theme)),
          Expanded(flex: 2, child: _cell(S.rolesTablePermissions, theme)),
          Expanded(flex: 2, child: _cell(S.status, theme)),
          Expanded(flex: 2, child: _cell(S.staffJoined, theme)),
          const SizedBox(width: StaffTable._actionWidth),
        ],
      ),
    );
  }

  Widget _cell(String label, ThemeData theme) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: adminMutedColor(theme),
      fontSize: AppFontSizes.size10,
      fontWeight: AppFontWeights.medium,
      height: AppTextHeights.line1_5,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
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
    final body = adminBodyColor(theme);
    final subtle = adminSubtleColor(theme);
    final date = dark ? AppColor.darkTextSecondary : AppColor.adminDate;
    final status = StaffStatusView.of(member.status);
    final contact = staffContactLine(member);
    final roles = staffRolesText(member);

    return Material(
      color: AppColor.transparent,
      child: InkWell(
        onTap: onManage,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: adminRowBorderColor(theme)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    StaffAvatar(member: member),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staffDisplayName(member),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: body,
                              fontSize: AppFontSizes.size11,
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
                                fontSize: AppFontSizes.size9,
                                height: AppTextHeights.line1_5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  roles,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: body,
                    fontSize: AppFontSizes.size10_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  staffPermissionsCount(member),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtle,
                    fontSize: AppFontSizes.size10_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AdminStatusBadge(
                    label: status.label,
                    color: status.color,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  staffJoined(member),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: date,
                    fontSize: AppFontSizes.size10_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              SizedBox(
                width: StaffTable._actionWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canManagePermissions)
                      StaffEditAction(onPressed: onEdit),
                    StaffPermissionAction(
                      canManage: canManagePermissions,
                      onPressed: onManage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StaffPermissionAction extends StatelessWidget {
  const StaffPermissionAction({
    super.key,
    required this.canManage,
    required this.onPressed,
  });

  final bool canManage;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = adminIsDark(theme)
        ? AppColor.secondaryColor
        : AppColor.adminAccent;
    return IconButton(
      tooltip: canManage ? S.staffManagePermissions : S.staffViewPermissions,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(30, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
      icon: AppIcon(
        canManage ? AppIcons.userSettings01 : AppIcons.eyeIcon,
        size: 16,
        color: canManage ? accent : adminMutedColor(theme),
      ),
    );
  }
}

/// يفتح بطاقة الموظف لتعديل الاسم والبريد والحالة والصورة.
class StaffEditAction extends StatelessWidget {
  const StaffEditAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = adminIsDark(theme)
        ? AppColor.secondaryColor
        : AppColor.adminAccent;
    return IconButton(
      tooltip: S.editStaffTitle,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(30, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
      icon: AppIcon(AppIcons.edit01, size: 16, color: accent),
    );
  }
}
