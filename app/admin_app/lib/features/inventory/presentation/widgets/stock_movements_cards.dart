import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

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
      separatorBuilder: (_, _) => const SizedBox(height: 10),
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
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
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: adminIsDark(theme)
                          ? typeColor.withValues(alpha: .16)
                          : Color.lerp(typeColor, AppColor.whiteColor, .88),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: HugeIcon(
                      icon: stockMovementTypeIcon(type),
                      size: 20,
                      color: adminFlagForeground(theme, typeColor),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                  const SizedBox(width: 8),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedPackage,
                    size: 14,
                    color: adminMutedColor(theme),
                  ),
                  const SizedBox(width: 6),
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
              const SizedBox(height: 9),
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
                          icon: HugeIcons.strokeRoundedCoins01,
                          label: S.stockMovementValue,
                          value: inventoryMoney(movement.movementValue),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _StatBox(
                          icon: HugeIcons.strokeRoundedInvoice01,
                          label: S.stockMovementUnitCost,
                          value: inventoryMoney(movement.unitCost),
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
                    icon: HugeIcons.strokeRoundedStore01,
                    size: 13,
                    color: adminMutedColor(theme),
                  ),
                  const SizedBox(width: 4),
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
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedUser,
                    size: 13,
                    color: adminMutedColor(theme),
                  ),
                  const SizedBox(width: 4),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedInvoice01,
                      size: 13,
                      color: adminMutedColor(theme),
                    ),
                    const SizedBox(width: 4),
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
  });

  final IconData icon;
  final String label;
  final String value;

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
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size10_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
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
