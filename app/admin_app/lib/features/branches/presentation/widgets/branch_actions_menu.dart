import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

enum BranchAction { edit, image, delivery, pricing, toggle, delete }

/// The compact menu that holds every action of one branch.
class BranchActionsMenu extends StatelessWidget {
  const BranchActionsMenu({
    super.key,
    required this.branch,
    required this.canManage,
    required this.canManagePricing,
    required this.onAction,
  });

  final AdminBranch branch;
  final bool canManage;
  final bool canManagePricing;
  final ValueChanged<BranchAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return PopupMenuButton<BranchAction>(
      key: Key('branch-menu-${branch.id}'),
      tooltip: S.branchesMenuTooltip,
      onSelected: onAction,
      itemBuilder: (context) => [
        if (canManage) ...[
          PopupMenuItem<BranchAction>(
            value: BranchAction.edit,
            child: _item(
              theme,
              icon: HugeIcons.strokeRoundedPencilEdit02,
              label: S.editBranch,
              direction: rtl,
            ),
          ),
          PopupMenuItem<BranchAction>(
            value: BranchAction.image,
            child: _item(
              theme,
              icon: HugeIcons.strokeRoundedImageAdd01,
              label: S.branchesImageAction,
              direction: rtl,
            ),
          ),
          PopupMenuItem<BranchAction>(
            value: BranchAction.delivery,
            child: _item(
              theme,
              icon: HugeIcons.strokeRoundedDeliveryTruck01,
              label: S.manageDelivery,
              direction: rtl,
            ),
          ),
        ],
        if (canManagePricing)
          PopupMenuItem<BranchAction>(
            value: BranchAction.pricing,
            child: _item(
              theme,
              icon: HugeIcons.strokeRoundedCoins01,
              label: S.manageBranchPricing,
              direction: rtl,
            ),
          ),
        if (canManage) ...[
          const PopupMenuDivider(),
          PopupMenuItem<BranchAction>(
            value: BranchAction.toggle,
            child: _item(
              theme,
              icon: branch.isActive
                  ? HugeIcons.strokeRoundedPause
                  : HugeIcons.strokeRoundedPlay,
              label: branch.isActive ? S.branchDeactivate : S.branchActivate,
              direction: rtl,
            ),
          ),
          PopupMenuItem<BranchAction>(
            value: BranchAction.delete,
            child: _item(
              theme,
              icon: HugeIcons.strokeRoundedDelete02,
              label: S.delete,
              direction: rtl,
              color: AppColor.errorColor,
            ),
          ),
        ],
      ],
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedMoreHorizontal,
        size: 18,
        color: adminMutedColor(theme),
      ),
    );
  }

  Widget _item(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool direction,
    Color? color,
  }) => Row(
    textDirection: direction ? TextDirection.rtl : TextDirection.ltr,
    children: [
      HugeIcon(icon: icon, size: 16, color: color ?? adminBodyColor(theme)),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color ?? adminBodyColor(theme),
            fontSize: AppFontSizes.size11,
            height: AppTextHeights.line1_5,
          ),
        ),
      ),
    ],
  );
}
