import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/kitchen/data/models/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/presentation/widgets/kitchen_format.dart';
import 'package:admin_app/features/kitchen/presentation/widgets/kitchen_ticket_card.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// The live kitchen board: four status columns on a wide screen, the same
/// columns as tabs on a narrow one.
class KitchenBoard extends StatefulWidget {
  const KitchenBoard({
    super.key,
    required this.tickets,
    required this.now,
    required this.canManage,
    required this.showBranch,
    required this.hasActiveFilters,
    required this.busyTicketIds,
    required this.busyItemIds,
    required this.onTicketStatus,
    required this.onToggleItem,
    required this.onClearFilters,
  });

  final List<AdminKitchenTicket> tickets;
  final DateTime now;
  final bool canManage;
  final bool showBranch;
  final bool hasActiveFilters;
  final Set<String> busyTicketIds;
  final Set<String> busyItemIds;
  final void Function(AdminKitchenTicket ticket, KitchenTicketStatus status)
  onTicketStatus;
  final ValueChanged<AdminKitchenTicketItem> onToggleItem;
  final VoidCallback onClearFilters;

  static const double wideBreakpoint = 1040;

  @override
  State<KitchenBoard> createState() => _KitchenBoardState();
}

class _KitchenBoardState extends State<KitchenBoard> {
  KitchenTicketStatus _selected = KitchenTicketStatus.queued;
  bool _pickedInitially = false;

  @override
  void initState() {
    super.initState();
    _pickInitialTab();
  }

  @override
  void didUpdateWidget(KitchenBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pickedInitially) _pickInitialTab();
  }

  /// Opens the first column that actually has work, so an empty "new orders"
  /// tab never hides a kitchen that is already preparing.
  void _pickInitialTab() {
    if (widget.tickets.isEmpty) return;
    _pickedInitially = true;
    for (final status in kKitchenBoardStatuses) {
      if (widget.tickets.any((ticket) => ticket.status == status)) {
        _selected = status;
        return;
      }
    }
  }

  List<AdminKitchenTicket> _ticketsFor(KitchenTicketStatus status) => widget
      .tickets
      .where((ticket) => ticket.status == status)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    if (widget.tickets.isEmpty) {
      return widget.hasActiveFilters
          ? AdminEmptyState(
              icon: HugeIcons.strokeRoundedChefHat,
              message: S.kitchenNoMatches,
              hint: S.kitchenNoMatchesHint,
              action: TextButton(
                onPressed: widget.onClearFilters,
                child: Text(S.clearFilters),
              ),
            )
          : AdminEmptyState(
              icon: HugeIcons.strokeRoundedChefHat,
              message: S.kitchenEmptyTitle,
              hint: S.kitchenEmptyHint,
            );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= KitchenBoard.wideBreakpoint) {
          return _WideBoard(
            ticketsFor: _ticketsFor,
            now: widget.now,
            canManage: widget.canManage,
            showBranch: widget.showBranch,
            busyTicketIds: widget.busyTicketIds,
            busyItemIds: widget.busyItemIds,
            onTicketStatus: widget.onTicketStatus,
            onToggleItem: widget.onToggleItem,
          );
        }
        return _NarrowBoard(
          selected: _selected,
          onSelected: (status) {
            setState(() {
              _selected = status;
              _pickedInitially = true;
            });
          },
          counts: {
            for (final status in kKitchenBoardStatuses)
              status: widget.tickets
                  .where((ticket) => ticket.status == status)
                  .length,
          },
          tickets: _ticketsFor(_selected),
          now: widget.now,
          canManage: widget.canManage,
          showBranch: widget.showBranch,
          busyTicketIds: widget.busyTicketIds,
          busyItemIds: widget.busyItemIds,
          onTicketStatus: widget.onTicketStatus,
          onToggleItem: widget.onToggleItem,
        );
      },
    );
  }
}

class _WideBoard extends StatelessWidget {
  const _WideBoard({
    required this.ticketsFor,
    required this.now,
    required this.canManage,
    required this.showBranch,
    required this.busyTicketIds,
    required this.busyItemIds,
    required this.onTicketStatus,
    required this.onToggleItem,
  });

  final List<AdminKitchenTicket> Function(KitchenTicketStatus status)
  ticketsFor;
  final DateTime now;
  final bool canManage;
  final bool showBranch;
  final Set<String> busyTicketIds;
  final Set<String> busyItemIds;
  final void Function(AdminKitchenTicket ticket, KitchenTicketStatus status)
  onTicketStatus;
  final ValueChanged<AdminKitchenTicketItem> onToggleItem;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < kKitchenBoardStatuses.length; index++) ...[
          if (index > 0) const SizedBox(width: 11),
          Expanded(
            child: _BoardColumn(
              status: kKitchenBoardStatuses[index],
              tickets: ticketsFor(kKitchenBoardStatuses[index]),
              now: now,
              canManage: canManage,
              showBranch: showBranch,
              busyTicketIds: busyTicketIds,
              busyItemIds: busyItemIds,
              onTicketStatus: onTicketStatus,
              onToggleItem: onToggleItem,
            ),
          ),
        ],
      ],
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.status,
    required this.tickets,
    required this.now,
    required this.canManage,
    required this.showBranch,
    required this.busyTicketIds,
    required this.busyItemIds,
    required this.onTicketStatus,
    required this.onToggleItem,
  });

  final KitchenTicketStatus status;
  final List<AdminKitchenTicket> tickets;
  final DateTime now;
  final bool canManage;
  final bool showBranch;
  final Set<String> busyTicketIds;
  final Set<String> busyItemIds;
  final void Function(AdminKitchenTicket ticket, KitchenTicketStatus status)
  onTicketStatus;
  final ValueChanged<AdminKitchenTicketItem> onToggleItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(status: status, count: tickets.length),
        const SizedBox(height: 8),
        Expanded(
          child: tickets.isEmpty
              ? _ColumnEmpty(status: status)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: tickets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return KitchenTicketCard(
                      key: Key('kitchen-ticket-${ticket.id}'),
                      ticket: ticket,
                      now: now,
                      canManage: canManage,
                      showBranch: showBranch,
                      isBusy: busyTicketIds.contains(ticket.id),
                      isItemBusy: busyItemIds.contains,
                      onStart: () =>
                          onTicketStatus(ticket, KitchenTicketStatus.preparing),
                      onReady: () =>
                          onTicketStatus(ticket, KitchenTicketStatus.ready),
                      onComplete: () =>
                          onTicketStatus(ticket, KitchenTicketStatus.completed),
                      onRecall: () =>
                          onTicketStatus(ticket, KitchenTicketStatus.preparing),
                      onToggleItem: onToggleItem,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NarrowBoard extends StatelessWidget {
  const _NarrowBoard({
    required this.selected,
    required this.onSelected,
    required this.counts,
    required this.tickets,
    required this.now,
    required this.canManage,
    required this.showBranch,
    required this.busyTicketIds,
    required this.busyItemIds,
    required this.onTicketStatus,
    required this.onToggleItem,
  });

  final KitchenTicketStatus selected;
  final ValueChanged<KitchenTicketStatus> onSelected;
  final Map<KitchenTicketStatus, int> counts;
  final List<AdminKitchenTicket> tickets;
  final DateTime now;
  final bool canManage;
  final bool showBranch;
  final Set<String> busyTicketIds;
  final Set<String> busyItemIds;
  final void Function(AdminKitchenTicket ticket, KitchenTicketStatus status)
  onTicketStatus;
  final ValueChanged<AdminKitchenTicketItem> onToggleItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (
                var index = 0;
                index < kKitchenBoardStatuses.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 6),
                _StatusTab(
                  key: Key('kitchen-tab-${kKitchenBoardStatuses[index].value}'),
                  status: kKitchenBoardStatuses[index],
                  count: counts[kKitchenBoardStatuses[index]] ?? 0,
                  selected: kKitchenBoardStatuses[index] == selected,
                  onTap: () => onSelected(kKitchenBoardStatuses[index]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 9),
        Expanded(
          child: tickets.isEmpty
              ? _ColumnEmpty(status: selected)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: tickets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return KitchenTicketCard(
                      key: Key('kitchen-ticket-${ticket.id}'),
                      ticket: ticket,
                      now: now,
                      canManage: canManage,
                      showBranch: showBranch,
                      isBusy: busyTicketIds.contains(ticket.id),
                      isItemBusy: busyItemIds.contains,
                      onStart: () =>
                          onTicketStatus(ticket, KitchenTicketStatus.preparing),
                      onReady: () =>
                          onTicketStatus(ticket, KitchenTicketStatus.ready),
                      onComplete: () =>
                          onTicketStatus(ticket, KitchenTicketStatus.completed),
                      onRecall: () =>
                          onTicketStatus(ticket, KitchenTicketStatus.preparing),
                      onToggleItem: onToggleItem,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.status, required this.count});

  final KitchenTicketStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final color = kitchenStatusColor(status);
    final foreground = adminFlagForeground(theme, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          color,
          Color.lerp(color, Colors.white, .9)!,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: dark ? .35 : .18)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: kitchenStatusIcon(status),
            size: 15,
            color: foreground,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              kitchenColumnLabel(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: AppFontSizes.size11_5,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_4,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              localizeDigits('$count'),
              style: TextStyle(
                color: foreground,
                fontSize: AppFontSizes.size9_5,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    super.key,
    required this.status,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final KitchenTicketStatus status;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final color = kitchenStatusColor(status);
    final foreground = selected
        ? adminFlagForeground(theme, color)
        : adminMutedColor(theme);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? adminFlagBackground(
                    theme,
                    color,
                    Color.lerp(color, Colors.white, .9)!,
                  )
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: .4)
                  : adminControlBorderColor(theme),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: kitchenStatusIcon(status),
                size: 14,
                color: selected ? foreground : adminMutedColor(theme),
              ),
              const SizedBox(width: 5),
              Text(
                kitchenColumnLabel(status),
                style: TextStyle(
                  color: foreground,
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: selected
                      ? AppFontWeights.bold
                      : AppFontWeights.medium,
                  height: AppTextHeights.line1_4,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.surface
                      : adminTintedSurfaceColor(theme),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  localizeDigits('$count'),
                  style: TextStyle(
                    color: selected
                        ? foreground
                        : dark
                        ? AppColor.darkTextSecondary
                        : AppColor.adminMuted,
                    fontSize: AppFontSizes.size9,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_4,
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

class _ColumnEmpty extends StatelessWidget {
  const _ColumnEmpty({required this.status});

  final KitchenTicketStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = adminMutedColor(theme);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: kitchenStatusIcon(status),
              size: 24,
              color: muted.withValues(alpha: .45),
            ),
            const SizedBox(height: 6),
            Text(
              S.kitchenEmptyColumn,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
