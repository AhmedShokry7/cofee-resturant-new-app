import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_cards.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_table.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class InventoryDirectory extends StatefulWidget {
  const InventoryDirectory({
    super.key,
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.search,
    required this.category,
    required this.statusFilter,
    required this.branchId,
    required this.filters,
    required this.isRefreshingRows,
    required this.canAdjust,
    required this.canEdit,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onBranchChanged,
    required this.onClearFilters,
    required this.onPageChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onMovement,
    required this.onDelete,
  });

  final List<AdminInventoryItem> items;

  /// The server-side total across every page.
  final int total;
  final int page;
  final int pages;
  final int pageSize;
  final String search;
  final String? category;
  final InventoryStatusFilter statusFilter;
  final String? branchId;
  final AdminInventoryFilters filters;
  final bool isRefreshingRows;
  final bool canAdjust;
  final bool canEdit;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<InventoryStatusFilter> onStatusChanged;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onAdd;
  final ValueChanged<AdminInventoryItem> onEdit;
  final ValueChanged<AdminInventoryItem> onMovement;
  final ValueChanged<AdminInventoryItem> onDelete;

  @override
  State<InventoryDirectory> createState() => _InventoryDirectoryState();
}

class _InventoryDirectoryState extends State<InventoryDirectory> {
  static const _cardsBreakpoint = 1120.0;

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(InventoryDirectory oldWidget) {
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
      widget.category != null ||
      widget.statusFilter != InventoryStatusFilter.all ||
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
          InventoryToolbar(
            searchController: _searchController,
            onSearchChanged: widget.onSearchChanged,
            statusFilter: widget.statusFilter,
            onStatusChanged: widget.onStatusChanged,
            category: widget.category,
            onCategoryChanged: widget.onCategoryChanged,
            branchId: widget.branchId,
            onBranchChanged: widget.onBranchChanged,
            categories: widget.filters.categories,
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
                        return InventoryCards(
                          items: widget.items,
                          canAdjust: widget.canAdjust,
                          canEdit: widget.canEdit,
                          onEdit: widget.onEdit,
                          onMovement: widget.onMovement,
                          onDelete: widget.onDelete,
                        );
                      }
                      return InventoryTable(
                        items: widget.items,
                        canAdjust: widget.canAdjust,
                        canEdit: widget.canEdit,
                        onEdit: widget.onEdit,
                        onMovement: widget.onMovement,
                        onDelete: widget.onDelete,
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
              labelBuilder: S.inventoryRowsLabel,
              onChanged: widget.onPageChanged,
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final noData = !_hasActiveFilters;
    return AdminEmptyState(
      icon: HugeIcons.strokeRoundedPackage,
      message: noData ? S.rawMaterialsEmpty : S.rawMaterialsNoMatches,
      hint: noData ? S.rawMaterialsEmptyHint : S.rawMaterialsNoMatchesHint,
      action: !noData
          ? TextButton(onPressed: _clearAll, child: Text(S.clearFilters))
          : widget.canEdit
          ? TextButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(HugeIcons.strokeRoundedAdd01, size: 16),
              label: Text(S.addRawMaterial),
            )
          : null,
    );
  }
}
