import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_format.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_icon.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class RoleTable extends StatelessWidget {
  const RoleTable({
    super.key,
    required this.roles,
    required this.onManage,
    required this.canManage,
  });

  final List<AdminRole> roles;
  final ValueChanged<AdminRole>? onManage;
  final bool canManage;

  static const _actionWidth = 44.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, 900), 1600)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _Header(),
                for (final role in roles)
                  _Row(
                    role: role,
                    canManage: canManage,
                    onManage: onManage == null ? null : () => onManage!(role),
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
  const _Header();

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
          Expanded(flex: 5, child: _cell(S.rolesTableRole, theme)),
          Expanded(flex: 2, child: _cell(S.rolesTableType, theme)),
          Expanded(flex: 5, child: _cell(S.rolesTablePermissions, theme)),
          const SizedBox(width: RoleTable._actionWidth),
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
  const _Row({required this.role, required this.canManage, this.onManage});

  final AdminRole role;
  final bool canManage;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = adminBodyColor(theme);
    final subtle = adminSubtleColor(theme);

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
                    RoleIcon(role: role),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roleDisplayName(role),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: body,
                              fontSize: AppFontSizes.size11,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                          Text(
                            roleCode(role),
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
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AdminStatusBadge(
                    label: roleTypeLabel(role),
                    color: roleTypeColor(role),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rolePermissionCount(role),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: body,
                        fontSize: AppFontSizes.size10_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      rolePermissionPreview(role),
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
              SizedBox(
                width: RoleTable._actionWidth,
                child: onManage == null
                    ? null
                    : Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _RoleActionButton(
                          onPressed: onManage!,
                          canManage: canManage,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleActionButton extends StatelessWidget {
  const _RoleActionButton({required this.onPressed, required this.canManage});

  final VoidCallback onPressed;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = adminIsDark(theme)
        ? AppColor.secondaryColor
        : AppColor.adminAccent;
    return IconButton(
      tooltip: canManage ? S.roleManagePermissions : S.roleViewPermissions,
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
