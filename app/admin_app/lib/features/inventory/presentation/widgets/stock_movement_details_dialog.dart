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
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

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
        horizontal: screen.width < AppBreakpoints.pageCanvas
            ? AppSpacing.md
            : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _EventBanner(movement: movement),
                      const SizedBox(height: AppSizes.px14),
                      _StatsGrid(movement: movement),
                      const SizedBox(height: AppSizes.px14),
                      _InfoSection(movement: movement),
                      const SizedBox(height: AppSizes.px12),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminFlagBackground(theme, color, AppColor.adminAccentSurface),
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: AppIcon(
              stockMovementTypeIcon(type),
              size: 21,
              color: adminFlagForeground(theme, color),
            ),
          ),
          const SizedBox(width: AppSizes.px10),
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
                const SizedBox(height: AppSizes.px6),
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
                        AppIcon(
                          AppIcons.calendar03,
                          size: 12,
                          color: adminMutedColor(theme),
                        ),
                        const SizedBox(width: AppSizes.px4),
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
        icon: AppIcons.exchange01,
        label: S.stockMovementQuantityChange,
        value: inventoryDelta(movement.quantityDelta, movement.unit),
        valueColor: changeColor,
      ),
      _DetailTile(
        icon: AppIcons.package,
        label: S.stockMovementBalanceAfter,
        value: inventoryQuantity(movement.balanceAfter, movement.unit),
      ),
      _DetailTile(
        icon: AppIcons.invoice01,
        label: S.stockMovementUnitCost,
        value: inventoryMoney(movement.unitCost),
        isMoney: true,
      ),
      _DetailTile(
        icon: AppIcons.coins01,
        label: S.stockMovementValue,
        value: inventoryMoney(movement.movementValue),
        isMoney: true,
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
    this.isMoney = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = this.valueColor ?? adminBodyColor(theme);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 17, color: adminMutedColor(theme)),
          const SizedBox(width: AppSizes.px8),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: valueColor,
                          fontSize: AppFontSizes.size11_5,
                          fontWeight: AppFontWeights.bold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                    if (isMoney) ...[
                      const SizedBox(width: AppSizes.px4),
                      CurrencyIcon(size: 14, color: valueColor),
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

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.movement});

  final AdminStockMovement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = movement.reference?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            icon: AppIcons.calendar03,
            label: S.stockMovementDateTime,
            value: inventoryDateTimeLabel(movement.createdAt),
          ),
          _InfoRow(
            icon: AppIcons.store01,
            label: S.movementBranch,
            value: inventoryMovementBranchName(movement),
            caption: movement.branchCode.isEmpty ? null : movement.branchCode,
          ),
          _InfoRow(
            icon: AppIcons.user,
            label: S.stockMovementsTableActor,
            value: inventoryMovementActorName(movement),
            caption: movement.actorEmail,
          ),
          _InfoRow(
            icon: AppIcons.invoice01,
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
          AppIcon(icon, size: 14, color: adminMutedColor(theme)),
          const SizedBox(width: AppSizes.px8),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
          const SizedBox(height: AppSizes.px4),
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
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
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
