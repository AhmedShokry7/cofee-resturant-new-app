import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_actions_menu.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class InventoryCards extends StatelessWidget {
  const InventoryCards({
    super.key,
    required this.items,
    required this.canAdjust,
    required this.canEdit,
    required this.onEdit,
    required this.onMovement,
    required this.onDelete,
  });

  final List<AdminInventoryItem> items;
  final bool canAdjust;
  final bool canEdit;
  final ValueChanged<AdminInventoryItem> onEdit;
  final ValueChanged<AdminInventoryItem> onMovement;
  final ValueChanged<AdminInventoryItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return _InventoryCard(
          key: Key('inventory-card-${item.id}'),
          item: item,
          canAdjust: canAdjust,
          canEdit: canEdit,
          onEdit: () => onEdit(item),
          onMovement: () => onMovement(item),
          onDelete: () => onDelete(item),
        );
      },
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    super.key,
    required this.item,
    required this.canAdjust,
    required this.canEdit,
    required this.onEdit,
    required this.onMovement,
    required this.onDelete,
  });

  final AdminInventoryItem item;
  final bool canAdjust;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onMovement;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = inventoryStatusColor(item.status);
    final sku = item.sku?.trim() ?? '';
    final subtitle = sku.isEmpty
        ? inventoryCategoryLabel(item.category)
        : '$sku · ${inventoryCategoryLabel(item.category)}';

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: canEdit ? onEdit : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: adminIsDark(theme)
                          ? statusColor.withValues(alpha: .16)
                          : Color.lerp(statusColor, AppColor.whiteColor, .88),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: HugeIcon(
                      icon: inventoryStatusIcon(item.status),
                      size: 21,
                      color: adminFlagForeground(theme, statusColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inventoryMaterialName(item),
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
                          subtitle,
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
                  const SizedBox(width: 6),
                  AdminStatusBadge(
                    label: inventoryStatusLabel(item.status),
                    color: statusColor,
                  ),
                  if (canAdjust || canEdit)
                    InventoryActionsMenu(
                      item: item,
                      canAdjust: canAdjust,
                      canEdit: canEdit,
                      onAction: (action) {
                        switch (action) {
                          case InventoryMaterialAction.movement:
                            onMovement();
                          case InventoryMaterialAction.edit:
                            onEdit();
                          case InventoryMaterialAction.delete:
                            onDelete();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
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
                          icon: HugeIcons.strokeRoundedPackage,
                          label: S.inventoryTableOnHand,
                          value: inventoryQuantity(
                            item.quantityOnHand,
                            item.unit,
                          ),
                          caption: inventoryMoney(item.unitCost),
                          valueColor: item.isOut
                              ? AppColor.trendNegative
                              : item.isLow
                              ? AppColor.adminWarning
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _StatBox(
                          icon: HugeIcons.strokeRoundedAlert02,
                          label: S.inventoryTableReorder,
                          value: inventoryQuantity(
                            item.reorderLevel,
                            item.unit,
                          ),
                          caption: S.materialReorderLevel,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _StatBox(
                          icon: HugeIcons.strokeRoundedCoins01,
                          label: S.inventoryTableValue,
                          value: inventoryMoney(item.stockValue),
                          caption: S.materialUnitCost,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    size: 13,
                    color: adminMutedColor(theme),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.lastMovementAt == null
                          ? S.inventoryNoMovement
                          : S.inventoryMetricMovementHint(
                              inventoryRelativeLabel(item.lastMovementAt),
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
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

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 14, color: adminMutedColor(theme)),
          const SizedBox(width: 6),
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
                    color: valueColor ?? adminBodyColor(theme),
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
