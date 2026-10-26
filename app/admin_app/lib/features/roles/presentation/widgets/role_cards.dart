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
import 'package:admin_app/shared/widgets/admin_labeled_value.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class RoleCards extends StatelessWidget {
  const RoleCards({
    super.key,
    required this.roles,
    required this.onManage,
    required this.canManage,
  });

  final List<AdminRole> roles;
  final ValueChanged<AdminRole>? onManage;
  final bool canManage;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: roles.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px8),
    itemBuilder: (context, index) {
      final role = roles[index];
      return _RoleCard(
        role: role,
        canManage: canManage,
        onManage: onManage == null ? null : () => onManage!(role),
      );
    },
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.canManage, this.onManage});

  final AdminRole role;
  final bool canManage;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.lg);
    final body = adminBodyColor(theme);
    final subtle = adminSubtleColor(theme);
    final accent = adminIsDark(theme)
        ? AppColor.secondaryColor
        : AppColor.adminAccent;

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
                  RoleIcon(role: role, size: 38),
                  const SizedBox(width: AppSizes.px10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roleDisplayName(role),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: body,
                            fontSize: AppFontSizes.size12,
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
                            fontSize: AppFontSizes.size10,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.px8),
                  AdminStatusBadge(
                    label: roleTypeLabel(role),
                    color: roleTypeColor(role),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.px10),
              AdminLabeledValue(
                label: S.rolesTablePermissions,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rolePermissionCount(role),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: body,
                        fontSize: AppFontSizes.size11,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      rolePermissionPreview(role),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtle,
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ],
                ),
              ),
              if (onManage != null) ...[
                const SizedBox(height: AppSizes.px4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: onManage,
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                    icon: AppIcon(
                      canManage ? AppIcons.userSettings01 : AppIcons.eyeIcon,
                      size: 15,
                      color: accent,
                    ),
                    label: Text(
                      canManage
                          ? S.roleManagePermissions
                          : S.roleViewPermissions,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
