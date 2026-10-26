import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/widgets/stock_movements_cards.dart';
import 'package:admin_app/features/inventory/presentation/widgets/stock_movements_table.dart';
import 'package:admin_app/features/inventory/presentation/widgets/stock_movements_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class StockMovementsDirectory extends StatefulWidget {
  const StockMovementsDirectory({
    super.key,
    required this.movements,
    required this.total,
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.search,
    required this.type,
    required this.period,
    required this.branchId,
    required this.filters,
    required this.isRefreshingRows,
    required this.canAdjust,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onPeriodChanged,
    required this.onBranchChanged,
    required this.onClearFilters,
    required this.onPageChanged,
    required this.onOpen,
    required this.onRecordMovement,
  });

  final List<AdminStockMovement> movements;

  /// The server-side total across every page.
  final int total;
  final int page;
  final int pages;
  final int pageSize;
  final String search;
  final StockMovementTypeFilter type;
  final StockMovementPeriod period;
  final String? branchId;
  final AdminInventoryFilters filters;
  final bool isRefreshingRows;
  final bool canAdjust;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<StockMovementTypeFilter> onTypeChanged;
  final ValueChanged<StockMovementPeriod> onPeriodChanged;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<AdminStockMovement> onOpen;
  final VoidCallback onRecordMovement;

  @override
  State<StockMovementsDirectory> createState() =>
      _StockMovementsDirectoryState();
}

class _StockMovementsDirectoryState extends State<StockMovementsDirectory> {
  static const _cardsBreakpoint = 1180.0;

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(StockMovementsDirectory oldWidget) {
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

  bool get _hasActiveFilters =>
      widget.search.trim().isNotEmpty ||
      widget.type != StockMovementTypeFilter.all ||
      widget.period != StockMovementPeriod.all ||
      widget.branchId != null;

  void _clearAll() {
    _searchController.clear();
    widget.onClearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StockMovementsToolbar(
            searchController: _searchController,
            onSearchChanged: widget.onSearchChanged,
            type: widget.type,
            onTypeChanged: widget.onTypeChanged,
            period: widget.period,
            onPeriodChanged: widget.onPeriodChanged,
            branchId: widget.branchId,
            onBranchChanged: widget.onBranchChanged,
            branches: widget.filters.branches,
            onClearFilters: widget.onClearFilters,
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 2,
            child: widget.isRefreshingRows
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColor.adminAccent,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 9),
          Expanded(
            child: widget.total == 0
                ? _emptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < _cardsBreakpoint) {
                        return StockMovementsCards(
                          movements: widget.movements,
                          onOpen: widget.onOpen,
                        );
                      }
                      return StockMovementsTable(
                        movements: widget.movements,
                        onOpen: widget.onOpen,
                      );
                    },
                  ),
          ),
          if (widget.total > 0)
            AdminPagination(
              page: widget.page,
              pages: widget.pages,
              count: widget.total,
              pageSize: widget.pageSize,
              labelBuilder: S.stockMovementsRowsLabel,
              onChanged: widget.onPageChanged,
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final noData = !_hasActiveFilters;
    return AdminEmptyState(
      icon: HugeIcons.strokeRoundedExchange01,
      message: noData ? S.stockMovementsEmpty : S.stockMovementsNoMatches,
      hint: noData ? S.stockMovementsEmptyHint : S.stockMovementsNoMatchesHint,
      action: !noData
          ? TextButton(onPressed: _clearAll, child: Text(S.clearFilters))
          : widget.canAdjust
          ? TextButton.icon(
              onPressed: widget.onRecordMovement,
              icon: const Icon(HugeIcons.strokeRoundedAdd01, size: 16),
              label: Text(S.stockMovementAction),
            )
          : null,
    );
  }
}
