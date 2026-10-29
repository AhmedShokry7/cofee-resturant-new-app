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

class StockMovementsCards extends StatelessWidget {
  const StockMovementsCards({
    super.key,
    required this.movements,
    required this.onOpen,
  });

  final List<AdminStockMovement> movements;
  final ValueChanged<AdminStockMovement> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: movements.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px10),
      itemBuilder: (context, index) {
        final movement = movements[index];
        return _MovementCard(
          key: Key('stock-movement-card-${movement.id}'),
          movement: movement,
          onOpen: () => onOpen(movement),
        );
      },
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({
    super.key,
    required this.movement,
    required this.onOpen,
  });

  final AdminStockMovement movement;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = movement.movementType;
    final typeColor = stockMovementTypeColor(type);
    final changeColor = movement.quantityDelta < 0
        ? AppColor.trendNegative
        : movement.quantityDelta > 0
        ? AppColor.trendPositive
        : adminMutedColor(theme);
    final sku = movement.materialSku?.trim() ?? '';

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onOpen,
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
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: adminIsDark(theme)
                          ? typeColor.withValues(alpha: .16)
                          : Color.lerp(typeColor, AppColor.whiteColor, .88),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: AppIcon(
                      stockMovementTypeIcon(type),
                      size: 20,
                      color: adminFlagForeground(theme, typeColor),
                    ),
                  ),
                  const SizedBox(width: AppSizes.px10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stockMovementTypeLabel(type),
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
                  const SizedBox(width: AppSizes.px8),
                  Text(
                    inventoryDelta(movement.quantityDelta, movement.unit),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: changeColor,
                      fontSize: AppFontSizes.size12_5,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.px10),
              Row(
                children: [
                  AppIcon(
                    AppIcons.package,
                    size: 14,
                    color: adminMutedColor(theme),
                  ),
                  const SizedBox(width: AppSizes.px6),
                  Expanded(
                    child: Text(
                      inventoryMovementMaterialName(movement),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size11,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  if (sku.isNotEmpty)
                    Text(
                      sku,
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
                          label: S.stockMovementBalanceAfter,
                          value: inventoryQuantity(
                            movement.balanceAfter,
                            movement.unit,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _StatBox(
                          icon: AppIcons.coins01,
                          label: S.stockMovementValue,
                          value: inventoryMoney(movement.movementValue),
                          isMoney: true,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _StatBox(
                          icon: AppIcons.invoice01,
                          label: S.stockMovementUnitCost,
                          value: inventoryMoney(movement.unitCost),
                          isMoney: true,
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
                    AppIcons.store01,
                    size: 13,
                    color: adminMutedColor(theme),
                  ),
                  const SizedBox(width: AppSizes.px4),
                  Expanded(
                    child: Text(
                      inventoryMovementBranchName(movement),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  AppIcon(
                    AppIcons.user,
                    size: 13,
                    color: adminMutedColor(theme),
                  ),
                  const SizedBox(width: AppSizes.px4),
                  Flexible(
                    child: Text(
                      inventoryMovementActorName(movement),
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
              if ((movement.reference?.trim() ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSizes.px6),
                Row(
                  children: [
                    AppIcon(
                      AppIcons.invoice01,
                      size: 13,
                      color: adminMutedColor(theme),
                    ),
                    const SizedBox(width: AppSizes.px4),
                    Expanded(
                      child: Text(
                        movement.reference!.trim(),
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
    this.isMoney = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = adminBodyColor(theme);
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
                    if (isMoney) ...[
                      const SizedBox(width: AppSizes.px4),
                      CurrencyIcon(size: 13, color: valueColor),
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
