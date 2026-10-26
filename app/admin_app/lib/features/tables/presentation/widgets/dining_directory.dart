import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/tables/data/models/dining_enums.dart';
import 'package:admin_app/features/tables/data/models/dining_overview.dart';
import 'package:admin_app/features/tables/data/models/dining_reservation.dart';
import 'package:admin_app/features/tables/data/models/dining_table.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_state.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_format.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_reservation_panel.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_table_card.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

/// The floor plan and its booking rail, split on wide screens and switched
/// between two views on compact ones.
class DiningDirectory extends StatefulWidget {
  const DiningDirectory({
    super.key,
    required this.tables,
    required this.allTables,
    required this.openReservations,
    required this.closedReservations,
    required this.branches,
    required this.branchId,
    required this.search,
    required this.area,
    required this.view,
    required this.canManage,
    required this.isRefreshing,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onAreaChanged,
    required this.onBranchChanged,
    required this.onViewChanged,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onAddTable,
    required this.onAddReservation,
    required this.onEditTable,
    required this.onBookTable,
    required this.onOpenReservation,
    required this.onToggleTable,
    required this.onDeleteTable,
    required this.onEditReservation,
    required this.onSeatReservation,
    required this.onCompleteReservation,
    required this.onCancelReservation,
    required this.onNoShowReservation,
  });

  final List<DiningTable> tables;
  final List<DiningTable> allTables;
  final List<DiningReservation> openReservations;
  final List<DiningReservation> closedReservations;
  final List<DiningBranch> branches;
  final String? branchId;
  final String search;
  final DiningArea? area;
  final DiningView view;
  final bool canManage;
  final bool isRefreshing;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DiningArea?> onAreaChanged;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<DiningView> onViewChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final VoidCallback onAddTable;
  final VoidCallback onAddReservation;
  final ValueChanged<DiningTable> onEditTable;
  final ValueChanged<DiningTable> onBookTable;
  final ValueChanged<DiningTable> onOpenReservation;
  final ValueChanged<DiningTable> onToggleTable;
  final ValueChanged<DiningTable> onDeleteTable;
  final ValueChanged<DiningReservation> onEditReservation;
  final ValueChanged<DiningReservation> onSeatReservation;
  final ValueChanged<DiningReservation> onCompleteReservation;
  final ValueChanged<DiningReservation> onCancelReservation;
  final ValueChanged<DiningReservation> onNoShowReservation;

  @override
  State<DiningDirectory> createState() => _DiningDirectoryState();
}

class _DiningDirectoryState extends State<DiningDirectory> {
  static const double _splitBreakpoint = 980;

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(DiningDirectory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search &&
        _searchController.text.trim() != widget.search) {
      _searchController.value = TextEditingValue(
        text: widget.search,
        selection: TextSelection.collapsed(offset: widget.search.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _splitBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AdminDirectoryPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 15,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _toolbar(compact: false),
                      const SizedBox(height: 12),
                      Expanded(child: _tablesContent()),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 13),
              SizedBox(
                width: 328,
                child: AdminDirectoryPanel(
                  padding: const EdgeInsets.fromLTRB(13, 14, 13, 12),
                  child: _reservationPane(),
                ),
              ),
            ],
          );
        }

        return AdminDirectoryPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(compact: true),
              const SizedBox(height: 10),
              _ViewSwitch(
                value: widget.view,
                counts: [
                  widget.allTables.length,
                  widget.openReservations.length,
                ],
                onChanged: widget.onViewChanged,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: widget.view == DiningView.tables
                    ? _tablesContent()
                    : _reservationPane(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolbar({required bool compact}) {
    final selectedBranch = _selectedBranch();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AdminSearchField(
                controller: _searchController,
                onChanged: widget.onSearchChanged,
                hintText: S.tablesSearchHint,
              ),
            ),
            if (widget.branches.isNotEmpty) ...[
              const SizedBox(width: 8),
              _BranchChip(
                name:
                    selectedBranch?.nameFor(AppLocale.instance.language) ??
                    S.tablesFilterBranch,
                icon: HugeIcons.strokeRoundedStore01,
                branches: widget.branches,
                selectedId: widget.branchId,
                enabled: widget.branches.length > 1,
                onChanged: widget.onBranchChanged,
              ),
            ],
            const SizedBox(width: 8),
            _RefreshButton(
              busy: widget.isRefreshing,
              onPressed: widget.onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 9),
        _AreaChips(
          allTables: widget.allTables,
          selected: widget.area,
          onChanged: widget.onAreaChanged,
        ),
        if (widget.hasActiveFilters) ...[
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: widget.onClearFilters,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                size: 13,
                color: AppColor.adminMuted,
              ),
              label: Text(
                S.clearFilters,
                style: TextStyle(
                  fontSize: AppFontSizes.size9_5,
                  color: adminMutedColor(Theme.of(context)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  DiningBranch? _selectedBranch() {
    for (final branch in widget.branches) {
      if (branch.id == widget.branchId) return branch;
    }
    return null;
  }

  Widget _tablesContent() {
    if (widget.allTables.isEmpty) {
      return AdminEmptyState(
        icon: HugeIcons.strokeRoundedTable01,
        message: S.tablesEmptyTitle,
        hint: S.tablesEmptyHint,
        action: widget.canManage
            ? TextButton.icon(
                onPressed: widget.onAddTable,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  size: 15,
                  color: AppColor.adminAccent,
                ),
                label: Text(
                  S.addTable,
                  style: const TextStyle(fontSize: AppFontSizes.size10),
                ),
              )
            : null,
      );
    }
    if (widget.tables.isEmpty) {
      return AdminEmptyState(
        icon: HugeIcons.strokeRoundedSearch01,
        message: S.tablesNoMatches,
        hint: S.tablesNoMatchesHint,
        action: TextButton(
          onPressed: widget.onClearFilters,
          child: Text(S.clearFilters),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 780
            ? 3
            : width >= 520
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 2),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 11,
            mainAxisSpacing: 11,
            mainAxisExtent: columns == 1 ? 192 : 204,
          ),
          itemCount: widget.tables.length,
          itemBuilder: (context, index) {
            final table = widget.tables[index];
            return DiningTableCard(
              table: table,
              canManage: widget.canManage,
              onEdit: () => widget.onEditTable(table),
              onBook: () => widget.onBookTable(table),
              onOpenReservation: () => widget.onOpenReservation(table),
              onToggleActive: () => widget.onToggleTable(table),
              onDelete: () => widget.onDeleteTable(table),
            );
          },
        );
      },
    );
  }

  Widget _reservationPane() {
    final hasTables = widget.allTables.isNotEmpty;
    return DiningReservationPanel(
      open: widget.openReservations,
      closed: widget.closedReservations,
      canManage: widget.canManage,
      onAdd: hasTables ? widget.onAddReservation : null,
      onEdit: widget.onEditReservation,
      onSeat: widget.onSeatReservation,
      onComplete: widget.onCompleteReservation,
      onCancel: widget.onCancelReservation,
      onNoShow: widget.onNoShowReservation,
      emptyMessage: widget.hasActiveFilters
          ? S.tablesReservationsNoMatches
          : S.tablesReservationsEmpty,
      emptyHint: widget.hasActiveFilters
          ? S.tablesReservationsNoMatchesHint
          : S.tablesReservationsEmptyHint,
    );
  }
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  final DiningView value;
  final List<int> counts;
  final ValueChanged<DiningView> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segment(
              context,
              view: DiningView.tables,
              label: S.tablesViewTables,
              count: counts.isNotEmpty ? counts.first : 0,
              icon: HugeIcons.strokeRoundedTable01,
              key: const Key('dining-view-tables'),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _segment(
              context,
              view: DiningView.reservations,
              label: S.tablesViewReservations,
              count: counts.length > 1 ? counts[1] : 0,
              icon: HugeIcons.strokeRoundedCalendar01,
              key: const Key('dining-view-reservations'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required DiningView view,
    required String label,
    required int count,
    required IconData icon,
    required Key key,
  }) {
    final theme = Theme.of(context);
    final selected = view == value;
    final foreground = selected
        ? adminHeadingColor(theme)
        : adminMutedColor(theme);
    return Material(
      key: key,
      color: selected ? theme.colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: selected ? null : () => onChanged(view),
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                size: 14,
                color: selected ? AppColor.adminAccent : foreground,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: AppFontSizes.size10,
                    fontWeight: selected
                        ? AppFontWeights.bold
                        : AppFontWeights.medium,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  localizeDigits('$count'),
                  style: TextStyle(
                    color: foreground.withValues(alpha: .8),
                    fontSize: AppFontSizes.size8_5,
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaChips extends StatelessWidget {
  const _AreaChips({
    required this.allTables,
    required this.selected,
    required this.onChanged,
  });

  final List<DiningTable> allTables;
  final DiningArea? selected;
  final ValueChanged<DiningArea?> onChanged;

  int _count(DiningArea? area) => area == null
      ? allTables.length
      : allTables.where((table) => table.area == area).length;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _AreaChip(
          label: S.tablesAreaAll,
          count: _count(null),
          icon: HugeIcons.strokeRoundedMenu01,
          selected: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final area in DiningArea.values)
          _AreaChip(
            label: diningAreaLabel(area),
            count: _count(area),
            icon: diningAreaIcon(area),
            selected: selected == area,
            onTap: () => onChanged(area),
          ),
      ],
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? adminFlagForeground(theme, AppColor.adminAccent)
        : adminMutedColor(theme);
    return Material(
      color: selected
          ? adminFlagBackground(
              theme,
              AppColor.adminAccent,
              AppColor.adminAccentSurface,
            )
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColor.adminAccent.withValues(alpha: .4)
                  : adminControlBorderColor(theme),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: icon,
                size: 13,
                color: selected ? AppColor.adminAccent : foreground,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: AppFontSizes.size9_5,
                  fontWeight: selected
                      ? AppFontWeights.bold
                      : AppFontWeights.medium,
                  height: AppTextHeights.line1_5,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColor.adminAccent.withValues(alpha: .14)
                        : adminTintedSurfaceColor(theme),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    localizeDigits('$count'),
                    style: TextStyle(
                      color: foreground,
                      fontSize: AppFontSizes.size8,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    required this.name,
    required this.icon,
    required this.branches,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final String name;
  final IconData icon;
  final List<DiningBranch> branches;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size10_5,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          HugeIcon(icon: icon, size: 15, color: adminMutedColor(theme)),
        ],
      ),
    );

    if (!enabled) {
      return Tooltip(message: name, child: chip);
    }

    return PopupMenuButton<String>(
      tooltip: S.tablesFilterBranch,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final branch in branches)
          PopupMenuItem<String>(
            value: branch.id,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: branch.id == selectedId
                      ? const HugeIcon(
                          icon: HugeIcons.strokeRoundedTick01,
                          size: 15,
                          color: AppColor.adminAccent,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    branch.nameFor(AppLocale.instance.language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: AppFontSizes.size11,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: chip,
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: S.refresh,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: busy ? null : onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 37,
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: adminControlBorderColor(theme)),
            ),
            child: busy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: adminMutedColor(theme),
                    ),
                  )
                : HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    size: 16,
                    color: adminMutedColor(theme),
                  ),
          ),
        ),
      ),
    );
  }
}
