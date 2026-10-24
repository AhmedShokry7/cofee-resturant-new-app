import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';

/// The branches whose name, code or address holds [search].
List<AdminBranch> filterBranches(List<AdminBranch> branches, String search) {
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return branches;
  return branches
      .where(
        (b) =>
            b.nameAr.toLowerCase().contains(q) ||
            b.nameEn.toLowerCase().contains(q) ||
            b.code.toLowerCase().contains(q) ||
            b.address.toLowerCase().contains(q),
      )
      .toList(growable: false);
}

/// The grid of branch cards.
class BranchRecords extends StatelessWidget {
  const BranchRecords({
    super.key,
    required this.branches,
    this.search = '',
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
    this.onChangeImage,
    this.onManageDelivery,
    this.onManagePricing,
  });

  /// Every loaded branch; the grid filters them with [search].
  final List<AdminBranch> branches;

  /// The word the admin is looking for.
  final String search;

  final ValueChanged<AdminBranch>? onEdit;
  final ValueChanged<AdminBranch>? onDelete;
  final ValueChanged<AdminBranch>? onToggleActive;
  final ValueChanged<AdminBranch>? onChangeImage;
  final ValueChanged<AdminBranch>? onManageDelivery;
  final ValueChanged<AdminBranch>? onManagePricing;

  List<AdminBranch> get _filtered => filterBranches(branches, search);

  @override
  Widget build(BuildContext context) {
    final branches = _filtered;
    if (branches.isEmpty) {
      return Center(
        child: Text(
          S.noBranchesFound,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns;
        if (width > 1400) {
          columns = 4;
        } else if (width > 1100) {
          columns = 3;
        } else if (width > 800) {
          columns = 2;
        } else {
          columns = 1;
        }

        final cardWidth = (width - (columns - 1) * AppDimensions.md) / columns;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppDimensions.md,
            mainAxisSpacing: AppDimensions.md,
            childAspectRatio: cardWidth / (cardWidth * 0.3 + 236),
          ),
          itemCount: branches.length,
          itemBuilder: (context, index) {
            final branch = branches[index];
            return BranchCard(
              branch: branch,
              onEdit: onEdit == null ? null : () => onEdit!(branch),
              onDelete: onDelete == null ? null : () => onDelete!(branch),
              onToggleActive: onToggleActive == null
                  ? null
                  : () => onToggleActive!(branch),
              onChangeImage: onChangeImage == null
                  ? null
                  : () => onChangeImage!(branch),
              onManageDelivery: onManageDelivery == null
                  ? null
                  : () => onManageDelivery!(branch),
              onManagePricing: onManagePricing == null
                  ? null
                  : () => onManagePricing!(branch),
            );
          },
        );
      },
    );
  }
}

/// A branch card: icon header, name and address, footer actions.
class BranchCard extends StatelessWidget {
  const BranchCard({
    super.key,
    required this.branch,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
    this.onChangeImage,
    this.onManageDelivery,
    this.onManagePricing,
  });

  final AdminBranch branch;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;
  final VoidCallback? onChangeImage;
  final VoidCallback? onManageDelivery;
  final VoidCallback? onManagePricing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;

    return Container(
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(color: AppColor.recordBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Header - takes remaining space
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(
                  color: AppColor.secondaryColor,
                  child: Center(
                    child: Icon(
                      HugeIcons.strokeRoundedStore01,
                      size: 48,
                      color: AppColor.primaryColor,
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: AppDimensions.recordImageInset / 2,
                  end: AppDimensions.recordImageInset / 2,
                  child: _ActiveBadge(
                    isActive: branch.isActive,
                    onTap: onToggleActive,
                  ),
                ),
                PositionedDirectional(
                  bottom: AppDimensions.recordImageInset / 2,
                  start: AppDimensions.recordImageInset / 2,
                  child: Material(
                    color: AppColor.whiteColor,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        branch.code,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColor.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.nameFor(language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColor.recordTextStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      HugeIcons.strokeRoundedLocation01,
                      size: 13,
                      color: AppColor.greyColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        branch.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColor.greyColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (branch.phone != null && branch.phone!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedCall02,
                        size: 13,
                        color: AppColor.greyColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          branch.phone!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColor.greyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (branch.opensAt != null || branch.closesAt != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedClock01,
                        size: 13,
                        color: AppColor.greyColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${branch.opensAt ?? '--:--'} - ${branch.closesAt ?? '--:--'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColor.greyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppDimensions.xs),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: OutlinedButton.icon(
                          onPressed: onManageDelivery,
                          icon: const Icon(
                            Icons.local_shipping_outlined,
                            size: 16,
                          ),
                          label: Text(
                            S.manageDelivery,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColor.primaryColor,
                            side: const BorderSide(
                              color: AppColor.recordBorder,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ),
                    if (onManagePricing != null) ...[
                      const SizedBox(width: AppDimensions.xs),
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: OutlinedButton.icon(
                            onPressed: onManagePricing,
                            icon: const Icon(
                              HugeIcons.strokeRoundedDollar01,
                              size: 16,
                            ),
                            label: Text(
                              S.manageBranchPricing,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColor.primaryColor,
                              side: const BorderSide(
                                color: AppColor.recordBorder,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Footer
          _BranchCardFooter(
            isActive: branch.isActive,
            onEdit: onEdit,
            onDelete: onDelete,
            onToggleActive: onToggleActive,
          ),
        ],
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.isActive, this.onTap});

  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isActive ? AppColor.primaryColor : AppColor.errorColor,
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive
                    ? HugeIcons.strokeRoundedCheckmarkCircle01
                    : HugeIcons.strokeRoundedCancelCircle,
                size: 12,
                color: AppColor.whiteColor,
              ),
              const SizedBox(width: 4),
              Text(
                isActive ? S.active : S.inactive,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColor.whiteColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchCardFooter extends StatelessWidget {
  const _BranchCardFooter({
    required this.isActive,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  final bool isActive;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColor.recordBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FooterAction(
              icon: HugeIcons.strokeRoundedEdit01,
              label: S.edit,
              color: AppColor.recordText,
              onTap: onEdit,
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: AppColor.recordBorder),
                ),
              ),
              child: _FooterAction(
                icon: isActive
                    ? HugeIcons.strokeRoundedCheckmarkCircle01
                    : HugeIcons.strokeRoundedCancelCircle,
                label: isActive ? S.active : S.inactive,
                color: AppColor.primaryColor,
                onTap: onToggleActive,
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: AppColor.recordBorder),
                ),
              ),
              child: _FooterAction(
                icon: HugeIcons.strokeRoundedDelete01,
                label: S.delete,
                color: AppColor.errorColor,
                onTap: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: AppDimensions.recordFooterHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
