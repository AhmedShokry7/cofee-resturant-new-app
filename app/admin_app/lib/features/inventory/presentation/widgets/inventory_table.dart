import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_actions_menu.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class InventoryTable extends StatelessWidget {
  const InventoryTable({
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

  static const _minWidth = 1080.0;
  static const _onHandWidth = 145.0;
  static const _reorderWidth = 120.0;
  static const _valueWidth = 135.0;
  static const _statusWidth = 100.0;
  static const _lastMovementWidth = 155.0;
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
                for (final item in items)
                  _Row(
                    key: Key('inventory-row-${item.id}'),
                    item: item,
                    canAdjust: canAdjust,
                    canEdit: canEdit,
                    onEdit: () => onEdit(item),
                    onMovement: () => onMovement(item),
                    onDelete: () => onDelete(item),
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
          Expanded(child: _cell(S.inventoryTableMaterial, theme)),
          SizedBox(
            width: InventoryTable._onHandWidth,
            child: _cell(S.inventoryTableOnHand, theme),
          ),
          SizedBox(
            width: InventoryTable._reorderWidth,
            child: _cell(S.inventoryTableReorder, theme),
          ),
          SizedBox(
            width: InventoryTable._valueWidth,
            child: _cell(S.inventoryTableValue, theme),
          ),
          SizedBox(
            width: InventoryTable._statusWidth,
            child: _cell(S.status, theme),
          ),
          SizedBox(
            width: InventoryTable._lastMovementWidth,
            child: _cell(S.inventoryTableLastMovement, theme),
          ),
          const SizedBox(width: InventoryTable._actionWidth),
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
    final body = adminBodyColor(theme);
    final statusColor = inventoryStatusColor(item.status);
    final sku = item.sku?.trim() ?? '';
    final subtitle = sku.isEmpty
        ? inventoryCategoryLabel(item.category)
        : '$sku · ${inventoryCategoryLabel(item.category)}';

    return Material(
      color: AppColor.transparent,
      child: InkWell(
        onTap: canEdit ? onEdit : null,
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
                    _MaterialIcon(status: item.status, color: statusColor),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inventoryMaterialName(item),
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
                  ],
                ),
              ),
              SizedBox(
                width: InventoryTable._onHandWidth,
                child: _ValueCell(
                  value: inventoryQuantity(item.quantityOnHand, item.unit),
                  caption: inventoryMoney(item.unitCost),
                  valueColor: item.isOut
                      ? AppColor.trendNegative
                      : item.isLow
                      ? AppColor.adminWarning
                      : body,
                ),
              ),
              SizedBox(
                width: InventoryTable._reorderWidth,
                child: _ValueCell(
                  value: inventoryQuantity(item.reorderLevel, item.unit),
                  caption: S.materialReorderLevel,
                ),
              ),
              SizedBox(
                width: InventoryTable._valueWidth,
                child: _ValueCell(
                  value: inventoryMoney(item.stockValue),
                  caption: inventoryMoney(item.unitCost),
                ),
              ),
              SizedBox(
                width: InventoryTable._statusWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AdminStatusBadge(
                    label: inventoryStatusLabel(item.status),
                    color: statusColor,
                  ),
                ),
              ),
              SizedBox(
                width: InventoryTable._lastMovementWidth,
                child: _ValueCell(
                  value: item.lastMovementAt == null
                      ? S.inventoryNoMovement
                      : inventoryRelativeLabel(item.lastMovementAt),
                  caption: item.lastMovementAt == null
                      ? '—'
                      : inventoryDateLabel(item.lastMovementAt),
                ),
              ),
              SizedBox(
                width: InventoryTable._actionWidth,
                child: canAdjust || canEdit
                    ? Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: InventoryActionsMenu(
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

class _MaterialIcon extends StatelessWidget {
  const _MaterialIcon({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: adminIsDark(theme)
            ? color.withValues(alpha: .16)
            : Color.lerp(color, AppColor.whiteColor, .88),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: AppIcon(
        inventoryStatusIcon(status),
        size: 19,
        color: adminFlagForeground(theme, color),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({
    required this.value,
    required this.caption,
    this.valueColor,
  });

  final String value;
  final String caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? adminBodyColor(theme),
            fontSize: AppFontSizes.size10_5,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_5,
          ),
        ),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: adminSubtleColor(theme),
            fontSize: AppFontSizes.size8_5,
            height: AppTextHeights.line1_4,
          ),
        ),
      ],
    );
  }
}
