import 'dart:math' as math;

import 'package:flutter/material.dart';

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

class BranchTable extends StatelessWidget {
  const BranchTable({
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

  static const _minWidth = 1080.0;
  static const _contactWidth = 185.0;
  static const _operationsWidth = 180.0;
  static const _coverageWidth = 160.0;
  static const _statusWidth = 95.0;
  static const _actionWidth = 36.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, _minWidth), 1760)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _Header(),
                for (final branch in branches)
                  _Row(
                    key: Key('branch-row-${branch.id}'),
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
          Expanded(child: _cell(S.branchesTableBranch, theme)),
          SizedBox(
            width: BranchTable._contactWidth,
            child: _cell(S.branchesTableContact, theme),
          ),
          SizedBox(
            width: BranchTable._operationsWidth,
            child: _cell(S.branchesTableOperations, theme),
          ),
          SizedBox(
            width: BranchTable._coverageWidth,
            child: _cell(S.branchesTableCoverage, theme),
          ),
          SizedBox(
            width: BranchTable._statusWidth,
            child: _cell(S.branchesTableStatus, theme),
          ),
          const SizedBox(width: BranchTable._actionWidth),
        ],
      ),
    );
  }

  Widget _cell(String label, ThemeData theme) => Text(
    label,
    textAlign: TextAlign.start,
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
    final dark = adminIsDark(theme);
    final body = adminBodyColor(theme);
    final hours = branchHours(branch);
    final phone = branch.phone?.trim() ?? '';
    final locationIssue = !branch.hasLocation;

    return Material(
      color: AppColor.transparent,
      child: InkWell(
        onTap: canManage ? onEdit : null,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: adminRowBorderColor(theme)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    AdminNetworkThumb(
                      imageUrl: branch.imageUrl,
                      size: 42,
                      icon: AppIcons.store01,
                    ),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branchName(branch),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: body,
                              fontSize: AppFontSizes.size11_5,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                          Text(
                            '${branch.code} · ${branch.address}',
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
                  ],
                ),
              ),
              SizedBox(
                width: BranchTable._contactWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phone.isEmpty ? S.branchesNoPhone : localizeDigits(phone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: phone.isEmpty ? adminMutedColor(theme) : body,
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      hours ?? S.branchesHoursNotSet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hours == null
                            ? (dark
                                  ? AppColor.adminWarning
                                  : AppColor.adminWarning)
                            : adminSubtleColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: BranchTable._operationsWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branchOrdersLabel(branch),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: branch.orders30d == 0
                            ? adminMutedColor(theme)
                            : (dark ? AppColor.darkText : AppColor.adminAmount),
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      branchLastOrder(branch),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminSubtleColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: BranchTable._coverageWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branchZonesLabel(branch),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: branch.zoneCount == 0
                            ? adminMutedColor(theme)
                            : body,
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      locationIssue
                          ? S.branchesMissingLocation
                          : branch.zoneCount == 0
                          ? S.branchesNoCoverage
                          : localizeDigits(
                              S.branchesStaffValue(branch.staffCount),
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: locationIssue || branch.zoneCount == 0
                            ? AppColor.adminWarning
                            : adminSubtleColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        fontWeight: locationIssue || branch.zoneCount == 0
                            ? AppFontWeights.semiBold
                            : AppFontWeights.regular,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: BranchTable._statusWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AdminStatusBadge(
                    label: branch.isActive ? S.active : S.inactive,
                    color: branch.isActive
                        ? AppColor.trendPositive
                        : AppColor.adminMuted,
                  ),
                ),
              ),
              SizedBox(
                width: BranchTable._actionWidth,
                child: canManage || canManagePricing
                    ? Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: BranchActionsMenu(
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
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
