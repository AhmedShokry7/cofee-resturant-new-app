import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/presentation/widgets/kitchen_format.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// One order as the kitchen sees it: the age, the table, the note and every
/// line, with the next action at the bottom.
class KitchenTicketCard extends StatelessWidget {
  const KitchenTicketCard({
    super.key,
    required this.ticket,
    required this.now,
    required this.canManage,
    required this.showBranch,
    required this.isBusy,
    required this.isItemBusy,
    required this.onStart,
    required this.onReady,
    required this.onComplete,
    required this.onRecall,
    required this.onToggleItem,
  });

  final AdminKitchenTicket ticket;
  final DateTime now;
  final bool canManage;
  final bool showBranch;
  final bool isBusy;
  final bool Function(String itemId) isItemBusy;
  final VoidCallback onStart;
  final VoidCallback onReady;
  final VoidCallback onComplete;
  final VoidCallback onRecall;
  final ValueChanged<AdminKitchenTicketItem> onToggleItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final statusColor = kitchenStatusColor(ticket.status);
    final late = ticket.isActive && kitchenIsLate(ticket.placedAt, now);
    final borderColor = late
        ? AppColor.trendNegative.withValues(alpha: dark ? .65 : .4)
        : adminCardBorderColor(theme);
    final branchName = ticket.branchNameFor(AppLocale.instance.language);
    final customer = ticket.customerName.isNotEmpty
        ? ticket.customerName
        : (ticket.isPos || ticket.isDineIn ? S.kitchenWalkIn : '');
    final progress = ticket.itemCount <= 0
        ? 0.0
        : (ticket.readyCount / ticket.itemCount).clamp(0.0, 1.0);
    final progressColor =
        ticket.itemCount > 0 && ticket.readyCount >= ticket.itemCount
        ? AppColor.trendPositive
        : AppColor.adminAccent;
    final tableNumber = ticket.tableNumber?.trim() ?? '';
    final fulfillment = ticket.isDineIn && tableNumber.isNotEmpty
        ? '${S.kitchenDineIn} · ${localizeDigits(S.kitchenTable(tableNumber))}'
        : kitchenFulfillmentLabel(ticket.fulfillmentType);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: dark
            ? const []
            : const [
                BoxShadow(
                  color: AppColor.inkWashFaint,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            color: late
                ? AppColor.trendNegative
                : statusColor.withValues(alpha: dark ? .8 : .55),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.none,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.orderNumber.trim().isEmpty
                            ? '—'
                            : ticket.orderNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminHeadingColor(theme),
                          fontSize: AppFontSizes.size13,
                          fontWeight: AppFontWeights.bold,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                    ),
                    if (late) ...[
                      const _LateBadge(),
                      const SizedBox(width: AppSizes.px6),
                    ],
                    _ElapsedChip(
                      label: kitchenElapsedLabel(ticket.placedAt, now),
                      late: late,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.px8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    _MetaPill(
                      icon: kitchenFulfillmentIcon(ticket.fulfillmentType),
                      label: fulfillment,
                    ),
                    _MetaPill(
                      icon: kitchenSourceIcon(ticket.orderSource),
                      label: kitchenSourceLabel(ticket.orderSource),
                      emphasize: ticket.isPos,
                    ),
                    if (showBranch && branchName.isNotEmpty)
                      _MetaPill(icon: AppIcons.store01, label: branchName),
                    if (customer.isNotEmpty)
                      _MetaPill(icon: AppIcons.user, label: customer),
                  ],
                ),
                if (ticket.itemCount > 0) ...[
                  const SizedBox(height: AppSizes.px8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizeDigits(
                            S.kitchenItemsProgress(
                              ticket.readyCount,
                              ticket.itemCount,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminMutedColor(theme),
                            fontSize: AppFontSizes.size9,
                            fontWeight: AppFontWeights.medium,
                            height: AppTextHeights.line1_4,
                          ),
                        ),
                      ),
                      Text(
                        localizeDigits('${(progress * 100).round()}%'),
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size8_5,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.px4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: adminTintedSurfaceColor(theme),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ],
                if (ticket.hasCustomerNote) ...[
                  const SizedBox(height: AppSizes.px8),
                  _CustomerNote(note: ticket.customerNote),
                ],
                const SizedBox(height: AppSizes.px6),
              ],
            ),
          ),
          if (ticket.items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                S.kitchenNoItems,
                style: TextStyle(
                  color: adminSubtleColor(theme),
                  fontSize: AppFontSizes.size9_5,
                  height: AppTextHeights.line1_5,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Column(
                children: [
                  for (var index = 0; index < ticket.items.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        indent: 6,
                        endIndent: 6,
                        color: adminRowBorderColor(theme),
                      ),
                    _KitchenItemRow(
                      item: ticket.items[index],
                      canManage: canManage && !isBusy,
                      busy: isItemBusy(ticket.items[index].id),
                      onTap: () => onToggleItem(ticket.items[index]),
                    ),
                  ],
                ],
              ),
            ),
          if (canManage) _footer(context, theme, dark),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, ThemeData theme, bool dark) {
    final content = switch (ticket.status) {
      KitchenTicketStatus.queued => _TicketAction(
        key: Key('kitchen-start-${ticket.id}'),
        label: S.kitchenStart,
        icon: AppIcons.playCircle,
        primary: true,
        loading: isBusy,
        onTap: onStart,
      ),
      KitchenTicketStatus.preparing => _TicketAction(
        key: Key('kitchen-ready-${ticket.id}'),
        label: S.kitchenMarkReady,
        icon: AppIcons.checkmarkCircle01,
        primary: true,
        loading: isBusy,
        onTap: onReady,
      ),
      KitchenTicketStatus.ready => Row(
        children: [
          Expanded(
            child: _TicketAction(
              key: Key('kitchen-complete-${ticket.id}'),
              label: S.kitchenComplete,
              icon: AppIcons.taskDone01,
              primary: true,
              loading: isBusy,
              onTap: onComplete,
            ),
          ),
          const SizedBox(width: AppSizes.px6),
          _TicketAction(
            key: Key('kitchen-recall-${ticket.id}'),
            label: S.kitchenRecall,
            icon: AppIcons.refresh,
            tooltip: S.kitchenRecallHint,
            loading: isBusy,
            onTap: isBusy ? null : onRecall,
          ),
        ],
      ),
      KitchenTicketStatus.completed => Row(
        children: [
          Expanded(
            child: Text(
              kitchenHandedOffLabel(ticket.completedAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_4,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.px6),
          _TicketAction(
            key: Key('kitchen-recall-${ticket.id}'),
            label: S.kitchenRecall,
            icon: AppIcons.refresh,
            tooltip: S.kitchenRecallHint,
            loading: isBusy,
            onTap: isBusy ? null : onRecall,
          ),
        ],
      ),
      KitchenTicketStatus.cancelled => const SizedBox.shrink(),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: content,
    );
  }
}

class _KitchenItemRow extends StatelessWidget {
  const _KitchenItemRow({
    required this.item,
    required this.canManage,
    required this.busy,
    required this.onTap,
  });

  final AdminKitchenTicketItem item;
  final bool canManage;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = item.isReady;
    final options = kitchenItemOptions(item);
    final note = item.note.trim();

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xxs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: adminTintedSurfaceColor(theme),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              localizeDigits('${item.quantity}×'),
              style: TextStyle(
                color: ready ? adminSubtleColor(theme) : adminBodyColor(theme),
                fontSize: AppFontSizes.size9_5,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_4,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nameFor(AppLocale.instance.language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ready
                        ? adminSubtleColor(theme)
                        : adminBodyColor(theme),
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                    decoration: ready ? TextDecoration.lineThrough : null,
                    decorationColor: adminSubtleColor(theme),
                  ),
                ),
                if (options.isNotEmpty)
                  Text(
                    options,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size9,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxs),
                          child: AppIcon(
                            AppIcons.note,
                            size: 10,
                            color: adminFlagForeground(
                              theme,
                              AppColor.adminWarning,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.px4),
                        Expanded(
                          child: Text(
                            note,
                            style: TextStyle(
                              color: adminFlagForeground(
                                theme,
                                AppColor.adminWarning,
                              ),
                              fontSize: AppFontSizes.size9,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.px6),
          _ItemCheck(status: item.status, busy: busy),
        ],
      ),
    );

    if (!canManage) return row;

    return Tooltip(
      message: ready ? S.kitchenItemMarkPending : S.kitchenItemMarkReady,
      child: Material(
        color: AppColor.transparent,
        child: InkWell(
          key: Key('kitchen-item-toggle-${item.id}'),
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: row,
        ),
      ),
    );
  }
}

class _ItemCheck extends StatelessWidget {
  const _ItemCheck({required this.status, required this.busy});

  final KitchenItemStatus status;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = status == KitchenItemStatus.ready;
    final preparing = status == KitchenItemStatus.preparing;
    final color = ready
        ? AppColor.trendPositive
        : preparing
        ? AppColor.adminInfo
        : adminMutedColor(theme);

    if (busy) {
      return SizedBox(
        width: AppSizes.px24,
        height: AppSizes.px24,
        child: Center(
          child: SizedBox(
            width: AppSizes.px14,
            height: AppSizes.px14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        ),
      );
    }

    return SizedBox(
      width: AppSizes.px24,
      height: AppSizes.px24,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 21,
          height: 21,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ready
                ? color
                : preparing
                ? adminFlagBackground(
                    theme,
                    AppColor.adminInfo,
                    AppColor.adminInfoSurface,
                  )
                : AppColor.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: ready
                  ? color
                  : preparing
                  ? color.withValues(alpha: .5)
                  : adminControlBorderColor(theme),
              width: 1.5,
            ),
          ),
          child: ready
              ? const AppIcon(
                  AppIcons.tick01,
                  size: 12,
                  color: AppColor.whiteColor,
                )
              : preparing
              ? const AppIcon(
                  AppIcons.timer01,
                  size: 11,
                  color: AppColor.adminInfo,
                )
              : null,
        ),
      ),
    );
  }
}

class _CustomerNote extends StatelessWidget {
  const _CustomerNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = adminFlagForeground(theme, AppColor.adminWarning);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminWarning,
          AppColor.adminWarningSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: AppIcon(AppIcons.note, size: 13, color: foreground),
          ),
          const SizedBox(width: AppSizes.px6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.kitchenCustomerNote,
                  style: TextStyle(
                    color: foreground,
                    fontSize: AppFontSizes.size8_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                Text(
                  note,
                  style: TextStyle(
                    color: foreground,
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_6,
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

class _LateBadge extends StatelessWidget {
  const _LateBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.trendNegative,
          AppColor.trendNegativeSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        S.kitchenLate,
        style: TextStyle(
          color: adminFlagForeground(theme, AppColor.trendNegative),
          fontSize: AppFontSizes.size8,
          fontWeight: AppFontWeights.bold,
          height: AppTextHeights.line1_4,
        ),
      ),
    );
  }
}

class _ElapsedChip extends StatelessWidget {
  const _ElapsedChip({required this.label, required this.late});

  final String label;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = late
        ? adminFlagForeground(theme, AppColor.trendNegative)
        : adminMutedColor(theme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: late
            ? adminFlagBackground(
                theme,
                AppColor.trendNegative,
                AppColor.trendNegativeSurface,
              )
            : adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.alarmClock, size: 11, color: color),
          const SizedBox(width: AppSizes.px4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: AppFontSizes.size9,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasize
        ? adminFlagForeground(theme, AppColor.adminInfo)
        : adminMutedColor(theme);
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: emphasize
            ? adminFlagBackground(
                theme,
                AppColor.adminInfo,
                AppColor.adminInfoSurface,
              )
            : adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 11, color: color),
          const SizedBox(width: AppSizes.px4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: AppFontSizes.size8_5,
                fontWeight: AppFontWeights.medium,
                height: AppTextHeights.line1_4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketAction extends StatelessWidget {
  const _TicketAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.loading = false,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool loading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final enabled = onTap != null && !loading;
    final background = primary
        ? AppColor.primaryColor
        : dark
        ? AppColor.darkSurfaceContainer
        : AppColor.recordCellBackground;
    final foreground = primary ? AppColor.whiteColor : adminBodyColor(theme);

    final content = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: enabled
            ? background
            : background.withValues(alpha: primary ? .5 : .7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: primary
            ? null
            : Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: AppSizes.px14,
              height: AppSizes.px14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primary ? AppColor.whiteColor : AppColor.adminAccent,
              ),
            )
          else
            AppIcon(icon, size: 14, color: foreground),
          const SizedBox(width: AppSizes.px6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground,
                fontSize: AppFontSizes.size10,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_4,
              ),
            ),
          ),
        ],
      ),
    );

    final button = Material(
      color: AppColor.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: content,
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
