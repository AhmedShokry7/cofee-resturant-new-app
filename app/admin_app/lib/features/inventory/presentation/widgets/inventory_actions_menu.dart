import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_item.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

enum InventoryMaterialAction { movement, edit, delete }

/// The compact menu that holds every action of one raw material.
class InventoryActionsMenu extends StatelessWidget {
  const InventoryActionsMenu({
    super.key,
    required this.item,
    required this.canAdjust,
    required this.canEdit,
    required this.onAction,
  });

  final AdminInventoryItem item;
  final bool canAdjust;
  final bool canEdit;
  final ValueChanged<InventoryMaterialAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return PopupMenuButton<InventoryMaterialAction>(
      key: Key('inventory-menu-${item.id}'),
      tooltip: S.stockMovementAction,
      onSelected: onAction,
      itemBuilder: (context) => [
        if (canAdjust)
          PopupMenuItem<InventoryMaterialAction>(
            value: InventoryMaterialAction.movement,
            child: _item(
              theme,
              icon: HugeIcons.strokeRoundedExchange01,
              label: S.stockMovementAction,
              direction: rtl,
            ),
          ),
        if (canEdit) ...[
          PopupMenuItem<InventoryMaterialAction>(
            value: InventoryMaterialAction.edit,
            child: _item(
              theme,
              icon: HugeIcons.strokeRoundedPencilEdit02,
              label: S.edit,
              direction: rtl,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<InventoryMaterialAction>(
            value: InventoryMaterialAction.delete,
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
