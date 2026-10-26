import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

Future<void> showStockMovementDetailsDialog({
  required BuildContext context,
  required AdminStockMovement movement,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => StockMovementDetailsDialog(movement: movement),
  );
}

class StockMovementDetailsDialog extends StatelessWidget {
  const StockMovementDetailsDialog({super.key, required this.movement});

  final AdminStockMovement movement;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .88, 700.0);
    return Dialog(
      key: const Key('stock-movement-details-dialog'),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 700 ? AppDimensions.md : AppDimensions.xxl,
        vertical: AppDimensions.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              AdminDialogHeader(
                title: S.stockMovementDetailsTitle,
                subtitle: inventoryMovementMaterialName(movement),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.lg,
                    AppDimensions.md,
                    AppDimensions.lg,
                    AppDimensions.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _EventBanner(movement: movement),
                      const SizedBox(height: 14),
                      _StatsGrid(movement: movement),
                      const SizedBox(height: 14),
                      _InfoSection(movement: movement),
                      const SizedBox(height: 12),
                      _NoteSection(movement: movement),
                    ],
                  ),
                ),
              ),
              _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.movement});

  final AdminStockMovement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = movement.movementType;
    final color = stockMovementTypeColor(type);
    final sku = movement.materialSku?.trim() ?? '';
    final branch = inventoryMovementBranchName(movement);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: adminFlagBackground(theme, color, AppColor.adminAccentSurface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: adminIsDark(theme) ? .35 : .16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: stockMovementTypeIcon(type),
              size: 21,
              color: adminFlagForeground(theme, color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inventoryMovementMaterialName(movement),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size14,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                if (sku.isNotEmpty)
                  Text(
                    sku,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size9,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AdminStatusBadge(
                      label: stockMovementTypeLabel(type),
                      color: color,
                    ),
                    AdminStatusBadge(label: branch, color: AppColor.adminInfo),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar03,
                          size: 12,
                          color: adminMutedColor(theme),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          inventoryRelativeLabel(movement.createdAt),
                          style: TextStyle(
                            color: adminMutedColor(theme),
                            fontSize: AppFontSizes.size9,
                            height: AppTextHeights.line1_4,
                          ),
                        ),
                      ],
                    ),
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.movement});

  final AdminStockMovement movement;

  @override
  Widget build(BuildContext context) {
    final changeColor = movement.quantityDelta < 0
        ? AppColor.trendNegative
        : movement.quantityDelta > 0
        ? AppColor.trendPositive
        : null;
    final tiles = <Widget>[
      _DetailTile(
        icon: HugeIcons.strokeRoundedExchange01,
        label: S.stockMovementQuantityChange,
        value: inventoryDelta(movement.quantityDelta, movement.unit),
        valueColor: changeColor,
      ),
      _DetailTile(
        icon: HugeIcons.strokeRoundedPackage,
        label: S.stockMovementBalanceAfter,
        value: inventoryQuantity(movement.balanceAfter, movement.unit),
      ),
      _DetailTile(
        icon: HugeIcons.strokeRoundedInvoice01,
        label: S.stockMovementUnitCost,
        value: inventoryMoney(movement.unitCost),
      ),
      _DetailTile(
        icon: HugeIcons.strokeRoundedCoins01,
        label: S.stockMovementValue,
        value: inventoryMoney(movement.movementValue),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 17, color: adminMutedColor(theme)),
          const SizedBox(width: 8),
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
                    fontSize: AppFontSizes.size8_5,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor ?? adminBodyColor(theme),
                    fontSize: AppFontSizes.size11_5,
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

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.movement});

  final AdminStockMovement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = movement.reference?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            icon: HugeIcons.strokeRoundedCalendar03,
            label: S.stockMovementDateTime,
            value: inventoryDateTimeLabel(movement.createdAt),
          ),
          _InfoRow(
            icon: HugeIcons.strokeRoundedStore01,
            label: S.movementBranch,
            value: inventoryMovementBranchName(movement),
            caption: movement.branchCode.isEmpty ? null : movement.branchCode,
          ),
          _InfoRow(
            icon: HugeIcons.strokeRoundedUser,
            label: S.stockMovementsTableActor,
            value: inventoryMovementActorName(movement),
            caption: movement.actorEmail,
          ),
          _InfoRow(
            icon: HugeIcons.strokeRoundedInvoice01,
            label: S.reference,
            value: reference.isEmpty ? S.stockMovementNoReference : reference,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 14, color: adminMutedColor(theme)),
          const SizedBox(width: 7),
          SizedBox(
            width: 116,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size10,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                if (caption != null && caption!.trim().isNotEmpty)
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size8_5,
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

class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.movement});

  final AdminStockMovement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = movement.note?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminRowBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.stockMovementNote,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size8_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            note.isEmpty ? S.stockMovementNoNote : note,
            style: TextStyle(
              color: note.isEmpty
                  ? adminMutedColor(theme)
                  : adminBodyColor(theme),
              fontSize: AppFontSizes.size10,
              height: AppTextHeights.line1_6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: adminIsDark(theme)
                ? AppColor.darkBorder
                : AppColor.adminRowBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            key: const Key('stock-movement-details-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.close),
          ),
        ],
      ),
    );
  }
}
