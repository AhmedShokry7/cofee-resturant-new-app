import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class StockMovementsTable extends StatelessWidget {
  const StockMovementsTable({
    super.key,
    required this.movements,
    required this.onOpen,
  });

  final List<AdminStockMovement> movements;
  final ValueChanged<AdminStockMovement> onOpen;

  static const _minWidth = 1180.0;
  static const _materialWidth = 200.0;
  static const _branchWidth = 140.0;
  static const _changeWidth = 125.0;
  static const _balanceWidth = 120.0;
  static const _valueWidth = 125.0;
  static const _actorWidth = 150.0;
  static const _chevronWidth = 28.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, _minWidth), 1800)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _Header(),
                for (final movement in movements)
                  _Row(
                    key: Key('stock-movement-row-${movement.id}'),
                    movement: movement,
                    onOpen: () => onOpen(movement),
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
          Expanded(child: _cell(S.stockMovementsTableMovement, theme)),
          SizedBox(
            width: StockMovementsTable._materialWidth,
            child: _cell(S.inventoryTableMaterial, theme),
          ),
          SizedBox(
            width: StockMovementsTable._branchWidth,
            child: _cell(S.stockMovementsTableBranch, theme),
          ),
          SizedBox(
            width: StockMovementsTable._changeWidth,
            child: _cell(S.stockMovementsTableQuantity, theme),
          ),
          SizedBox(
            width: StockMovementsTable._balanceWidth,
            child: _cell(S.stockMovementsTableBalance, theme),
          ),
          SizedBox(
            width: StockMovementsTable._valueWidth,
            child: _cell(S.stockMovementsTableValue, theme),
          ),
          SizedBox(
            width: StockMovementsTable._actorWidth,
            child: _cell(S.stockMovementsTableActor, theme),
          ),
          const SizedBox(width: StockMovementsTable._chevronWidth),
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
  const _Row({super.key, required this.movement, required this.onOpen});

  final AdminStockMovement movement;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = adminBodyColor(theme);
    final type = movement.movementType;
    final typeColor = stockMovementTypeColor(type);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sku = movement.materialSku?.trim() ?? '';
    final changeColor = movement.quantityDelta < 0
        ? AppColor.trendNegative
        : movement.quantityDelta > 0
        ? AppColor.trendPositive
        : adminMutedColor(theme);

    return Material(
      color: AppColor.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          height: 68,
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
                    _MovementIcon(type: type, color: typeColor),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stockMovementTypeLabel(type),
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
                            inventoryRelativeLabel(movement.createdAt),
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
                width: StockMovementsTable._materialWidth,
                child: _ValueCell(
                  value: inventoryMovementMaterialName(movement),
                  caption: sku.isEmpty ? '—' : sku,
                ),
              ),
              SizedBox(
                width: StockMovementsTable._branchWidth,
                child: _ValueCell(
                  value: inventoryMovementBranchName(movement),
                  caption: movement.branchCode.isEmpty
                      ? '—'
                      : movement.branchCode,
                ),
              ),
              SizedBox(
                width: StockMovementsTable._changeWidth,
                child: _ValueCell(
                  value: inventoryDelta(movement.quantityDelta, movement.unit),
                  valueColor: changeColor,
                  caption: S.stockMovementQuantityChange,
                ),
              ),
              SizedBox(
                width: StockMovementsTable._balanceWidth,
                child: _ValueCell(
                  value: inventoryQuantity(
                    movement.balanceAfter,
                    movement.unit,
                  ),
                  caption: S.inventoryTableOnHand,
                ),
              ),
              SizedBox(
                width: StockMovementsTable._valueWidth,
                child: _ValueCell(
                  value: inventoryMoney(movement.movementValue),
                  caption: inventoryMoney(movement.unitCost),
                  valueIsMoney: true,
                  captionIsMoney: true,
                ),
              ),
              SizedBox(
                width: StockMovementsTable._actorWidth,
                child: _ValueCell(
                  value: inventoryMovementActorName(movement),
                  caption: movement.actorEmail ?? '—',
                ),
              ),
              SizedBox(
                width: StockMovementsTable._chevronWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Tooltip(
                    message: S.stockMovementDetailsTitle,
                    child: AppIcon(
                      rtl ? AppIcons.arrowLeft01 : AppIcons.arrowRight01,
                      size: 16,
                      color: adminMutedColor(theme),
                    ),
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

class _MovementIcon extends StatelessWidget {
  const _MovementIcon({required this.type, required this.color});

  final InventoryMovementType? type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: adminIsDark(theme)
            ? color.withValues(alpha: .16)
            : Color.lerp(color, AppColor.whiteColor, .88),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: AppIcon(
        stockMovementTypeIcon(type),
        size: 18,
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
    this.valueIsMoney = false,
    this.captionIsMoney = false,
  });

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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  fontWeight: AppFontWeights.semiBold,
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
                textDirection: caption == '—' ? TextDirection.ltr : null,
                style: TextStyle(
                  color: captionColor,
                  fontSize: AppFontSizes.size8_5,
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
    );
  }
}
