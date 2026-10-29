import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_actions_menu.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

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
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px10),
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
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: canEdit ? onEdit : null,
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
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: adminIsDark(theme)
                          ? statusColor.withValues(alpha: .16)
                          : Color.lerp(statusColor, AppColor.whiteColor, .88),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: AppIcon(
                      inventoryStatusIcon(item.status),
                      size: 21,
                      color: adminFlagForeground(theme, statusColor),
                    ),
                  ),
                  const SizedBox(width: AppSizes.px10),
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
                  const SizedBox(width: AppSizes.px6),
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
                          icon: AppIcons.package,
                          label: S.inventoryTableOnHand,
                          value: inventoryQuantity(
                            item.quantityOnHand,
                            item.unit,
                          ),
                          caption: inventoryMoney(item.unitCost),
                          captionIsMoney: true,
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
                          icon: AppIcons.alert02,
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
                          icon: AppIcons.coins01,
                          label: S.inventoryTableValue,
                          value: inventoryMoney(item.stockValue),
                          valueIsMoney: true,
                          caption: S.materialUnitCost,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSizes.px10),
              Row(
                children: [
                  AppIcon(
                    AppIcons.clock01,
                    size: 13,
                    color: adminMutedColor(theme),
                  ),
                  const SizedBox(width: AppSizes.px4),
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
    this.valueIsMoney = false,
    this.captionIsMoney = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color? valueColor;
  final bool valueIsMoney;
  final bool captionIsMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = this.valueColor ?? adminBodyColor(theme);
    final captionColor = adminSubtleColor(theme);
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: valueColor,
                          fontSize: AppFontSizes.size10_5,
                          fontWeight: AppFontWeights.bold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                    if (valueIsMoney) ...[
                      const SizedBox(width: AppSizes.px4),
                      CurrencyIcon(size: 13, color: valueColor),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: captionColor,
                          fontSize: AppFontSizes.size7_5,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                    ),
                    if (captionIsMoney) ...[
                      const SizedBox(width: AppSizes.px4),
                      CurrencyIcon(size: 10, color: captionColor),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
