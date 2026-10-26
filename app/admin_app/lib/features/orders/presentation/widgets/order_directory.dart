import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_cards.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_directory_toolbar.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_controls.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_values.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filtering.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_status_tabs.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class OrderDirectory extends StatefulWidget {
  const OrderDirectory({
    super.key,
    required this.orders,
    required this.branches,
    required this.search,
    required this.onSearchChanged,
    required this.filters,
    required this.onFiltersChanged,
    required this.onChangeStatus,
    required this.onOpen,
    this.onExport,
    this.exporting,
  });

  final List<AdminOrder> orders;
  final List<AdminBranch> branches;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final OrderFilterValues filters;
  final ValueChanged<OrderFilterValues> onFiltersChanged;
  final void Function(AdminOrder order, String status) onChangeStatus;
  final ValueChanged<AdminOrder> onOpen;
  final ValueChanged<List<AdminOrder>>? onExport;
  final ValueListenable<bool>? exporting;

  @override
  State<OrderDirectory> createState() => _OrderDirectoryState();
}

class _OrderDirectoryState extends State<OrderDirectory> {
  static const _pageSize = 5;

  late final TextEditingController _searchController;
  int _page = 0;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(OrderDirectory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      _page = 0;
      if (_searchController.text.trim() != widget.search) {
        _searchController.value = TextEditingValue(
          text: widget.search,
          selection: TextSelection.collapsed(offset: widget.search.length),
        );
      }
    }
    if (oldWidget.filters != widget.filters) _page = 0;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminOrder> get _filtered => filterOrders(
    widget.orders,
    search: widget.search,
    status: widget.filters.status,
    fulfillment: widget.filters.fulfillment,
    paymentStatus: widget.filters.paymentStatus,
    branchId: widget.filters.branchId,
  );

  List<AdminOrder> get _branchOrders => widget.filters.branchId.isEmpty
      ? widget.orders
      : widget.orders
            .where((order) => order.branchId == widget.filters.branchId)
            .toList(growable: false);

  void _updateFilters(OrderFilterValues value) {
    setState(() => _page = 0);
    widget.onFiltersChanged(value);
  }

  void _clearFilters() {
    _searchController.clear();
    widget.onSearchChanged('');
    _updateFilters(const OrderFilterValues());
  }

  void _export() {
    final filtered = _filtered;
    if (filtered.isNotEmpty) widget.onExport?.call(filtered);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final filtered = _filtered;
    final pages = filtered.isEmpty ? 0 : (filtered.length / _pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final visible = filtered
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    final canClear = widget.filters.isActive || widget.search.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: dark
            ? const []
            : const [
                BoxShadow(
                  color: AppColor.inkWashFaint,
                  blurRadius: 24,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderDirectoryToolbar(
            searchController: _searchController,
            onSearchChanged: widget.onSearchChanged,
            filtersActive: widget.filters.isActive,
            filtersExpanded: _filtersExpanded,
            onToggleFilters: () =>
                setState(() => _filtersExpanded = !_filtersExpanded),
            onClearFilters: _clearFilters,
            onExport: _export,
            exporting: widget.exporting,
            exportEnabled: filtered.isNotEmpty,
          ),
          const SizedBox(height: AppSizes.px12),
          SizedBox(
            height: AppSizes.px36,
            child: OrderStatusTabs(
              orders: _branchOrders,
              value: widget.filters.status,
              onChanged: (value) =>
                  _updateFilters(widget.filters.copyWith(status: value)),
            ),
          ),
          if (_filtersExpanded) ...[
            const SizedBox(height: AppSizes.px10),
            OrderFilterControls(
              value: widget.filters,
              branches: widget.branches,
              onChanged: _updateFilters,
            ),
          ],
          const SizedBox(height: AppSizes.px12),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(
                    hasOrders: widget.orders.isNotEmpty,
                    canClear: canClear,
                    onClear: _clearFilters,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 840
                        ? OrderCards(
                            orders: visible,
                            onChangeStatus: widget.onChangeStatus,
                            onOpen: widget.onOpen,
                          )
                        : OrderTable(orders: visible, onOpen: widget.onOpen),
                  ),
          ),
          if (filtered.isNotEmpty)
            AdminPagination(
              page: page,
              pages: pages,
              count: filtered.length,
              pageSize: _pageSize,
              labelBuilder: (first, last, count) =>
                  S.ordersRowsLabel(first, last, count),
              onChanged: (value) => setState(() => _page = value),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasOrders,
    required this.canClear,
    required this.onClear,
  });

  final bool hasOrders;
  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.shoppingBag01,
              size: 38,
              color: muted.withValues(alpha: .6),
            ),
            const SizedBox(height: AppSizes.px10),
            Text(
              hasOrders ? S.noOrdersForFilter : S.noOrdersFound,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: AppFontSizes.size12,
                height: AppTextHeights.line1_5,
              ),
            ),
            if (canClear)
              TextButton(onPressed: onClear, child: Text(S.clearFilters)),
          ],
        ),
      ),
    );
  }
}
