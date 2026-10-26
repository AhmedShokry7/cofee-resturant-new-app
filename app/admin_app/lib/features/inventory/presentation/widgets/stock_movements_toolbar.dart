import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

class StockMovementsToolbar extends StatelessWidget {
  const StockMovementsToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.type,
    required this.onTypeChanged,
    required this.period,
    required this.onPeriodChanged,
    required this.branchId,
    required this.onBranchChanged,
    required this.branches,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final StockMovementTypeFilter type;
  final ValueChanged<StockMovementTypeFilter> onTypeChanged;
  final StockMovementPeriod period;
  final ValueChanged<StockMovementPeriod> onPeriodChanged;
  final String? branchId;
  final ValueChanged<String?> onBranchChanged;
  final List<AdminInventoryBranchOption> branches;
  final VoidCallback onClearFilters;

  bool get _hasActiveFilters =>
      type != StockMovementTypeFilter.all ||
      period != StockMovementPeriod.all ||
      branchId != null;

  String get _branchLabel {
    if (branchId == null) return S.inventoryFilterAllBranches;
    for (final branch in branches) {
      if (branch.id == branchId) return inventoryBranchName(branch);
    }
    return S.inventoryFilterAllBranches;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        final search = AdminSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
          hintText: S.stockMovementsSearchHint,
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _typeMenu(compact),
            _periodMenu(compact),
            if (branches.isNotEmpty) _branchMenu(compact),
            if (_hasActiveFilters)
              IconButton(
                tooltip: S.clearFilters,
                onPressed: onClearFilters,
                style: IconButton.styleFrom(
                  fixedSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 18,
                  color: AppColor.adminMuted,
                ),
              ),
          ],
        );
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: actions,
              ),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: constraints.maxWidth >= 1040 ? 330 : 250,
              child: search,
            ),
            const Spacer(),
            actions,
          ],
        );
      },
    );
  }

  Widget _typeMenu(bool compact) {
    final active = type != StockMovementTypeFilter.all;
    return PopupMenuButton<StockMovementTypeFilter>(
      tooltip: S.stockMovementTypeFilter,
      onSelected: onTypeChanged,
      itemBuilder: (context) => [
        for (final option in StockMovementTypeFilter.values)
          _menuItem<StockMovementTypeFilter>(
            context,
            value: option,
            label: inventoryTypeFilterLabel(option),
            selected: option == type,
          ),
      ],
      child: compact
          ? AdminToolbarIcon(
              icon: HugeIcons.strokeRoundedExchange01,
              active: active,
            )
          : AdminToolbarSurface(
              label: inventoryTypeFilterLabel(type),
              icon: HugeIcons.strokeRoundedExchange01,
              active: active,
            ),
    );
  }

  Widget _periodMenu(bool compact) {
    final active = period != StockMovementPeriod.all;
    return PopupMenuButton<StockMovementPeriod>(
      tooltip: S.stockPeriodLabel,
      onSelected: onPeriodChanged,
      itemBuilder: (context) => [
        for (final option in StockMovementPeriod.values)
          _menuItem<StockMovementPeriod>(
            context,
            value: option,
            label: inventoryPeriodLabel(option),
            selected: option == period,
          ),
      ],
      child: compact
          ? AdminToolbarIcon(
              icon: HugeIcons.strokeRoundedCalendar03,
              active: active,
            )
          : AdminToolbarSurface(
              label: inventoryPeriodLabel(period),
              icon: HugeIcons.strokeRoundedCalendar03,
              active: active,
            ),
    );
  }

  Widget _branchMenu(bool compact) {
    final active = branchId != null;
    return PopupMenuButton<String?>(
      tooltip: S.movementBranch,
      onSelected: onBranchChanged,
      itemBuilder: (context) => [
        _menuItem<String?>(
          context,
          value: null,
          label: S.inventoryFilterAllBranches,
          selected: branchId == null,
        ),
        for (final branch in branches)
          _menuItem<String?>(
            context,
            value: branch.id,
            label: inventoryBranchName(branch),
            selected: branch.id == branchId,
          ),
      ],
      child: compact
          ? AdminToolbarIcon(
              icon: HugeIcons.strokeRoundedStore01,
              active: active,
            )
          : AdminToolbarSurface(
              label: _branchLabel,
              icon: HugeIcons.strokeRoundedStore01,
              active: active,
            ),
    );
  }

  PopupMenuItem<T> _menuItem<T>(
    BuildContext context, {
    required T value,
    required String label,
    required bool selected,
  }) => PopupMenuItem<T>(
    value: value,
    child: Row(
      children: [
        SizedBox(
          width: 18,
          child: selected
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
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: adminBodyColor(Theme.of(context)),
              fontSize: AppFontSizes.size12,
            ),
          ),
        ),
      ],
    ),
  );
}
