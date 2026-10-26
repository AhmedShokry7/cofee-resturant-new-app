import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/dining_format.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

enum DiningTableAction { edit, book, toggle, delete }

/// One table or private room on the floor plan, with its live state.
class DiningTableCard extends StatelessWidget {
  const DiningTableCard({
    super.key,
    required this.table,
    required this.canManage,
    required this.onEdit,
    required this.onBook,
    required this.onOpenReservation,
    required this.onToggleActive,
    required this.onDelete,
  });

  final DiningTable table;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onBook;
  final VoidCallback onOpenReservation;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  bool get _canBook =>
      table.isActive &&
      table.status == DiningTableStatus.available &&
      !table.hasOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = diningTableStatusColor(table.status);
    final reservation = table.reservation;

    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: table.status == DiningTableStatus.occupied
              ? statusColor.withValues(alpha: adminIsDark(theme) ? .45 : .28)
              : adminCardBorderColor(theme),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: diningTableStatusSurface(table.status),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: AppIcon(
                  diningTableStatusIcon(table.status),
                  size: 18,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: AppSizes.px10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      table.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminHeadingColor(theme),
                        fontSize: AppFontSizes.size13,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                    Text(
                      localizeDigits(
                        '${diningAreaLabel(table.area)} • '
                        '${S.tableCapacity(table.capacity)}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage)
                _TableMenu(
                  table: table,
                  canBook: _canBook,
                  onAction: (action) {
                    switch (action) {
                      case DiningTableAction.edit:
                        onEdit();
                      case DiningTableAction.book:
                        onBook();
                      case DiningTableAction.toggle:
                        onToggleActive();
                      case DiningTableAction.delete:
                        onDelete();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSizes.px8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AdminStatusBadge(
              label: diningTableStatusLabel(table.status),
              color: statusColor,
            ),
          ),
          const SizedBox(height: AppSizes.px8),
          Expanded(child: _contextBlock(context)),
          if (canManage && (reservation != null || _canBook)) ...[
            const SizedBox(height: AppSizes.px4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: reservation != null ? onOpenReservation : onBook,
                style: TextButton.styleFrom(
                  foregroundColor: AppColor.adminAccent,
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 26),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: AppIcon(
                  reservation != null
                      ? AppIcons.calendar01
                      : AppIcons.calendarAdd01,
                  size: 14,
                  color: AppColor.adminAccent,
                ),
                label: Text(
                  reservation != null
                      ? S.tableOpenReservation
                      : S.tableBookAction,
                  style: const TextStyle(
                    fontSize: AppFontSizes.size10,
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return KeyedSubtree(
      key: Key('dining-table-${table.id}'),
      child: Opacity(
        opacity: table.isActive ? 1 : .72,
        child: Material(
          color: AppColor.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: canManage ? onEdit : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _contextBlock(BuildContext context) {
    final theme = Theme.of(context);
    final order = table.activeOrder;
    final reservation = table.reservation;
    final next = table.nextReservation;

    if (order != null) {
      return _ContextRow(
        icon: AppIcons.receiptDollar,
        color: AppColor.errorColor,
        title: localizeDigits(S.tableOrderOpen(order.orderNumber)),
        subtitle: formatMoneyWithCurrency(order.grandTotal),
      );
    }
    if (reservation != null) {
      return _ContextRow(
        icon: AppIcons.user,
        color: AppColor.adminInfo,
        title: reservation.customerName,
        subtitle: localizeDigits(
          '${S.tableGuests(reservation.partySize)} • '
          '${diningReservationWhen(reservation)}',
        ),
      );
    }
    if (next != null) {
      return _ContextRow(
        icon: AppIcons.calendar03,
        color: AppColor.adminWarning,
        title: localizeDigits(
          S.tableNextReservation(diningReservationWhen(next)),
        ),
        subtitle: localizeDigits(
          '${next.customerName} • ${S.tableGuests(next.partySize)}',
        ),
      );
    }
    final note = table.note.trim();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          AppIcon(
            note.isEmpty ? AppIcons.checkmarkCircle02 : AppIcons.note01,
            size: 14,
            color: adminMutedColor(theme),
          ),
          const SizedBox(width: AppSizes.px6),
          Expanded(
            child: Text(
              note.isEmpty ? S.tablesMetricAvailableHint : note,
              maxLines: 2,
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
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          color,
          Color.lerp(color, AppColor.whiteColor, .9)!,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 14, color: adminFlagForeground(theme, color)),
          const SizedBox(width: AppSizes.px6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminFlagForeground(theme, color),
                    fontSize: AppFontSizes.size10,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark
                        ? AppColor.darkTextSecondary
                        : adminMutedColor(theme),
                    fontSize: AppFontSizes.size8_8,
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

class _TableMenu extends StatelessWidget {
  const _TableMenu({
    required this.table,
    required this.canBook,
    required this.onAction,
  });

  final DiningTable table;
  final bool canBook;
  final ValueChanged<DiningTableAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return PopupMenuButton<DiningTableAction>(
      key: Key('dining-table-menu-${table.id}'),
      tooltip: S.tableMenuTooltip,
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem<DiningTableAction>(
          value: DiningTableAction.edit,
          child: _item(
            theme,
            icon: AppIcons.pencilEdit02,
            label: S.editTable,
            direction: rtl,
          ),
        ),
        if (canBook)
          PopupMenuItem<DiningTableAction>(
            value: DiningTableAction.book,
            child: _item(
              theme,
              icon: AppIcons.calendarAdd01,
              label: S.tableBookAction,
              direction: rtl,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<DiningTableAction>(
          value: DiningTableAction.toggle,
          child: _item(
            theme,
            icon: table.isActive ? AppIcons.pause : AppIcons.play,
            label: table.isActive ? S.tableDeactivate : S.tableActivate,
            direction: rtl,
          ),
        ),
        PopupMenuItem<DiningTableAction>(
          value: DiningTableAction.delete,
          child: _item(
            theme,
            icon: AppIcons.delete02,
            label: S.delete,
            direction: rtl,
            color: AppColor.errorColor,
          ),
        ),
      ],
      child: AppIcon(
        AppIcons.moreHorizontal,
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
      AppIcon(icon, size: 16, color: color ?? adminBodyColor(theme)),
      const SizedBox(width: AppSizes.px8),
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
