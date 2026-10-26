import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/models/customer_filter.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_cards.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_directory_toolbar.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_table.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class CustomerDirectory extends StatefulWidget {
  const CustomerDirectory({
    super.key,
    required this.customers,
    required this.search,
    required this.onSearchChanged,
    required this.onOpen,
    required this.onExport,
    required this.exporting,
  });

  final List<AdminCustomer> customers;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminCustomer> onOpen;
  final ValueChanged<List<AdminCustomer>> onExport;
  final ValueListenable<bool>? exporting;

  @override
  State<CustomerDirectory> createState() => _CustomerDirectoryState();
}

class _CustomerDirectoryState extends State<CustomerDirectory> {
  static const _pageSize = 5;

  late final TextEditingController _searchController;
  final Set<String> _selectedIds = <String>{};
  CustomerFilter _filter = CustomerFilter.all;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(CustomerDirectory oldWidget) {
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
    final knownIds = widget.customers.map((customer) => customer.id).toSet();
    _selectedIds.removeWhere((id) => !knownIds.contains(id));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminCustomer> get _filtered =>
      filterCustomers(widget.customers, search: widget.search, filter: _filter);

  void _toggle(AdminCustomer customer) {
    setState(() {
      if (!_selectedIds.remove(customer.id)) {
        _selectedIds.add(customer.id);
      }
    });
  }

  void _toggleAll() {
    final filtered = _filtered;
    final allSelected =
        filtered.isNotEmpty &&
        filtered.every((customer) => _selectedIds.contains(customer.id));
    setState(() {
      if (allSelected) {
        for (final customer in filtered) {
          _selectedIds.remove(customer.id);
        }
      } else {
        _selectedIds.addAll(filtered.map((customer) => customer.id));
      }
    });
  }

  void _setFilter(CustomerFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 0;
    });
  }

  void _clearFilter() {
    if (_filter == CustomerFilter.all) return;
    setState(() {
      _filter = CustomerFilter.all;
      _page = 0;
    });
  }

  void _clearAll() {
    _searchController.clear();
    widget.onSearchChanged('');
    setState(() {
      _filter = CustomerFilter.all;
      _page = 0;
    });
  }

  void _export() {
    final filtered = _filtered;
    final selected = filtered
        .where((customer) => _selectedIds.contains(customer.id))
        .toList(growable: false);
    final rows = selected.isEmpty ? filtered : selected;
    if (rows.isNotEmpty) widget.onExport(rows);
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
    final selectedCount = filtered
        .where((customer) => _selectedIds.contains(customer.id))
        .length;
    final allSelected = selectedCount == 0
        ? false
        : selectedCount == filtered.length
        ? true
        : null;

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
          CustomerDirectoryToolbar(
            searchController: _searchController,
            onSearchChanged: widget.onSearchChanged,
            filter: _filter,
            onFilterChanged: _setFilter,
            onClearFilter: _clearFilter,
            onExport: _export,
            exporting: widget.exporting,
            exportEnabled: filtered.isNotEmpty,
          ),
          const SizedBox(height: AppSizes.px14),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(
                    hasCustomers: widget.customers.isNotEmpty,
                    canClear:
                        _filter != CustomerFilter.all ||
                        widget.search.trim().isNotEmpty,
                    onClear: _clearAll,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      bool isSelected(AdminCustomer customer) =>
                          _selectedIds.contains(customer.id);
                      if (constraints.maxWidth < 840) {
                        return CustomerCards(
                          customers: visible,
                          isSelected: isSelected,
                          onToggle: _toggle,
                          onOpen: widget.onOpen,
                        );
                      }
                      return CustomerTable(
                        customers: visible,
                        isSelected: isSelected,
                        allSelected: allSelected,
                        onToggle: _toggle,
                        onToggleAll: _toggleAll,
                        onOpen: widget.onOpen,
                      );
                    },
                  ),
          ),
          if (filtered.isNotEmpty)
            AdminPagination(
              page: page,
              pages: pages,
              count: filtered.length,
              pageSize: _pageSize,
              labelBuilder: (first, last, count) =>
                  S.customersRowsLabel(first, last, count),
              onChanged: (value) => setState(() => _page = value),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasCustomers,
    required this.canClear,
    required this.onClear,
  });

  final bool hasCustomers;
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
              AppIcons.userMultiple,
              size: 38,
              color: muted.withValues(alpha: .6),
            ),
            const SizedBox(height: AppSizes.px10),
            Text(
              hasCustomers ? S.customersNoMatches : S.noCustomersFound,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: AppFontSizes.size12,
                height: AppTextHeights.line1_5,
              ),
            ),
            if (canClear)
              TextButton(
                onPressed: onClear,
                child: Text(S.customersClearFilter),
              ),
          ],
        ),
      ),
    );
  }
}
