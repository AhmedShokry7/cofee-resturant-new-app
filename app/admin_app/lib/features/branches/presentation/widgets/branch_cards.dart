import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_actions_menu.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_format.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class BranchCards extends StatelessWidget {
  const BranchCards({
    super.key,
    required this.branches,
    required this.canManage,
    required this.canManagePricing,
    required this.onEdit,
    required this.onChangeImage,
    required this.onManageDelivery,
    required this.onManagePricing,
    required this.onToggleActive,
    required this.onDelete,
  });

  final List<AdminBranch> branches;
  final bool canManage;
  final bool canManagePricing;
  final ValueChanged<AdminBranch> onEdit;
  final ValueChanged<AdminBranch> onChangeImage;
  final ValueChanged<AdminBranch> onManageDelivery;
  final ValueChanged<AdminBranch>? onManagePricing;
  final ValueChanged<AdminBranch> onToggleActive;
  final ValueChanged<AdminBranch> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: branches.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px10),
      itemBuilder: (context, index) {
        final branch = branches[index];
        return _BranchCard(
          key: Key('branch-card-${branch.id}'),
          branch: branch,
          canManage: canManage,
          canManagePricing: canManagePricing,
          onEdit: () => onEdit(branch),
          onChangeImage: () => onChangeImage(branch),
          onManageDelivery: () => onManageDelivery(branch),
          onManagePricing: onManagePricing == null
              ? null
              : () => onManagePricing!(branch),
          onToggleActive: () => onToggleActive(branch),
          onDelete: () => onDelete(branch),
        );
      },
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    super.key,
    required this.branch,
    required this.canManage,
    required this.canManagePricing,
    required this.onEdit,
    required this.onChangeImage,
    required this.onManageDelivery,
    required this.onManagePricing,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminBranch branch;
  final bool canManage;
  final bool canManagePricing;
  final VoidCallback onEdit;
  final VoidCallback onChangeImage;
  final VoidCallback onManageDelivery;
  final VoidCallback? onManagePricing;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = branchHours(branch);
    final phone = branch.phone?.trim() ?? '';
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: canManage ? onEdit : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AdminNetworkThumb(
                    imageUrl: branch.imageUrl,
                    size: 46,
                    icon: AppIcons.store01,
                  ),
                  const SizedBox(width: AppSizes.px10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branchName(branch),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size12,
                            fontWeight: AppFontWeights.bold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                        Text(
                          branch.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminSubtleColor(theme),
                            fontSize: AppFontSizes.size9,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.px6),
                  AdminStatusBadge(
                    label: branch.isActive ? S.active : S.inactive,
                    color: branch.isActive
                        ? AppColor.trendPositive
                        : AppColor.adminMuted,
                  ),
                  if (canManage || canManagePricing)
                    BranchActionsMenu(
                      branch: branch,
                      canManage: canManage,
                      canManagePricing: canManagePricing,
                      onAction: (action) {
                        switch (action) {
                          case BranchAction.edit:
                            onEdit();
                          case BranchAction.image:
                            onChangeImage();
                          case BranchAction.delivery:
                            onManageDelivery();
                          case BranchAction.pricing:
                            onManagePricing?.call();
                          case BranchAction.toggle:
                            onToggleActive();
                          case BranchAction.delete:
                            onDelete();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.px10),
              _MetaLine(
                icon: AppIcons.location01,
                text: branch.address,
                color: adminMutedColor(theme),
              ),
              const SizedBox(height: AppSizes.px10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 16) / 3;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: width,
                        child: _StatBox(
                          icon: AppIcons.shoppingBag01,
                          label: S.branchesTableOperations,
                          value: branchOrdersLabel(branch),
                          caption: branchLastOrder(branch),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _StatBox(
                          icon: AppIcons.userMultiple,
                          label: S.branchesStaff,
                          value: branchStaffLabel(branch),
                          caption: S.branchesStaffShort,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _StatBox(
                          icon: AppIcons.deliveryTruck01,
                          label: S.branchesZones,
                          value: branchZonesLabel(branch),
                          caption: S.branchesZonesShort,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSizes.px10),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MetaLine(
                    icon: AppIcons.call02,
                    text: phone.isEmpty
                        ? S.branchesNoPhone
                        : localizeDigits(phone),
                    color: phone.isEmpty
                        ? adminMutedColor(theme)
                        : adminBodyColor(theme),
                  ),
                  _MetaLine(
                    icon: AppIcons.clock01,
                    text: hours ?? S.branchesHoursNotSet,
                    color: hours == null
                        ? AppColor.adminWarning
                        : adminBodyColor(theme),
                  ),
                ],
              ),
              if (branch.needsSetup) ...[
                const SizedBox(height: AppSizes.px10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (!branch.hasLocation)
                      _IssueChip(
                        icon: AppIcons.location01,
                        label: S.branchesMissingLocation,
                      ),
                    if (branch.zoneCount == 0)
                      _IssueChip(
                        icon: AppIcons.deliveryTruck01,
                        label: S.branchesNoCoverage,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 14, color: adminMutedColor(theme)),
          const SizedBox(width: AppSizes.px6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size8,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size10_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminSubtleColor(theme),
                    fontSize: AppFontSizes.size7_5,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIcon(icon, size: 13, color: color),
      const SizedBox(width: AppSizes.px4),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: AppFontSizes.size9_5,
            height: AppTextHeights.line1_5,
          ),
        ),
      ),
    ],
  );
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminWarning,
          AppColor.adminWarningSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColor.adminWarning.withValues(
            alpha: adminIsDark(theme) ? .35 : .18,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            icon,
            size: 11,
            color: adminFlagForeground(theme, AppColor.adminWarning),
          ),
          const SizedBox(width: AppSizes.px4),
          Text(
            label,
            style: TextStyle(
              color: adminFlagForeground(theme, AppColor.adminWarning),
              fontSize: AppFontSizes.size8_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_4,
            ),
          ),
        ],
      ),
    );
  }
}
