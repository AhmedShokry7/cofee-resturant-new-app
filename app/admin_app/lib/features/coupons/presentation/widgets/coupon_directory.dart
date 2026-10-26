import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';
import 'package:admin_app/features/coupons/presentation/models/coupon_filter.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_cards.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_table.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_directory_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class CouponDirectory extends StatefulWidget {
  const CouponDirectory({
    super.key,
    required this.coupons,
    required this.search,
    required this.onSearchChanged,
    required this.canManage,
    required this.onAdd,
    required this.onOpen,
    required this.onCopy,
    required this.onToggle,
    required this.onDelete,
  });

  final List<AdminCoupon> coupons;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool canManage;
  final VoidCallback onAdd;
  final ValueChanged<AdminCoupon> onOpen;
  final ValueChanged<AdminCoupon> onCopy;
  final ValueChanged<AdminCoupon> onToggle;
  final ValueChanged<AdminCoupon> onDelete;

  @override
  State<CouponDirectory> createState() => _CouponDirectoryState();
}

class _CouponDirectoryState extends State<CouponDirectory> {
  static const _pageSize = 6;
  static const _cardsBreakpoint = 980.0;

  late final TextEditingController _searchController;
  AdminCouponFilter _filter = AdminCouponFilter.all;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(CouponDirectory oldWidget) {
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminCoupon> get _filtered =>
      filterCoupons(widget.coupons, search: widget.search, filter: _filter);

  void _onSearch(String value) {
    widget.onSearchChanged(value);
    setState(() => _page = 0);
  }

  void _setFilter(AdminCouponFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 0;
    });
  }

  void _clearFilters() => setState(() {
    _filter = AdminCouponFilter.all;
    _page = 0;
  });

  void _clearAll() {
    _searchController.clear();
    widget.onSearchChanged('');
    _clearFilters();
  }

  String _filterLabel(AdminCouponFilter option) {
    final count = option == AdminCouponFilter.all
        ? widget.coupons.length
        : widget.coupons.where(option.matches).length;
    return localizeDigits(S.couponsFilterOption(option.label, count));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final count = filtered.length;
    final pages = count == 0 ? 0 : (count / _pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final canClear =
        _filter != AdminCouponFilter.all || widget.search.trim().isNotEmpty;
    final visible = filtered
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);

    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDirectoryToolbar<AdminCouponFilter>(
            searchController: _searchController,
            onSearchChanged: _onSearch,
            searchHint: S.couponsSearchHint,
            filter: _filter,
            allLabel: _filterLabel(AdminCouponFilter.all),
            options: AdminCouponFilter.values,
            optionLabel: _filterLabel,
            onFilterChanged: _setFilter,
            onClearFilter: _clearFilters,
            filterLabel: S.couponsFilter,
            hasActiveFilter: _filter != AdminCouponFilter.all,
          ),
          const SizedBox(height: 13),
          Expanded(
            child: count == 0
                ? _emptyState(canClear: canClear)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < _cardsBreakpoint) {
                        return CouponCards(
                          coupons: visible,
                          canManage: widget.canManage,
                          onOpen: widget.onOpen,
                          onCopy: widget.onCopy,
                          onToggle: widget.onToggle,
                          onDelete: widget.onDelete,
                        );
                      }
                      return CouponTable(
                        coupons: visible,
                        canManage: widget.canManage,
                        onOpen: widget.onOpen,
                        onCopy: widget.onCopy,
                        onToggle: widget.onToggle,
                        onDelete: widget.onDelete,
                      );
                    },
                  ),
          ),
          if (count > 0)
            AdminPagination(
              page: page,
              pages: pages,
              count: count,
              pageSize: _pageSize,
              labelBuilder: S.couponsRowsLabel,
              onChanged: (value) => setState(() => _page = value),
            ),
        ],
      ),
    );
  }

  Widget _emptyState({required bool canClear}) {
    final noData = widget.coupons.isEmpty;
    return AdminEmptyState(
      icon: HugeIcons.strokeRoundedTicket01,
      message: noData ? S.couponsEmpty : S.couponsNoMatches,
      hint: noData ? S.couponsEmptyHint : null,
      action: canClear
          ? TextButton(onPressed: _clearAll, child: Text(S.clearFilters))
          : noData && widget.canManage
          ? TextButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(HugeIcons.strokeRoundedAdd01, size: 16),
              label: Text(S.couponsNew),
            )
          : null,
    );
  }
}
