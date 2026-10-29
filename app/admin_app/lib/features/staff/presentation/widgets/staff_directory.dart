import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/models/staff_filter.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_cards.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_table.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_directory_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class StaffDirectory extends StatefulWidget {
  const StaffDirectory({
    super.key,
    required this.staff,
    required this.search,
    required this.onSearchChanged,
    required this.canManagePermissions,
    required this.onManage,
    required this.onEdit,
  });

  final List<AdminStaffMember> staff;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool canManagePermissions;
  final ValueChanged<AdminStaffMember> onManage;
  final ValueChanged<AdminStaffMember> onEdit;

  @override
  State<StaffDirectory> createState() => _StaffDirectoryState();
}

class _StaffDirectoryState extends State<StaffDirectory> {
  static const _pageSize = 8;

  late final TextEditingController _searchController;
  StaffFilter _filter = StaffFilter.all;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(StaffDirectory oldWidget) {
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

  List<AdminStaffMember> get _filtered =>
      filterStaff(widget.staff, search: widget.search, filter: _filter);

  void _onSearchChanged(String value) {
    if (_page != 0) setState(() => _page = 0);
    widget.onSearchChanged(value);
  }

  void _setFilter(StaffFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 0;
    });
  }

  void _clearFilter() {
    if (_filter == StaffFilter.all) return;
    setState(() {
      _filter = StaffFilter.all;
      _page = 0;
    });
  }

  void _clearAll() {
    _searchController.clear();
    widget.onSearchChanged('');
    setState(() {
      _filter = StaffFilter.all;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pages = filtered.isEmpty ? 0 : (filtered.length / _pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final visible = filtered
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    final searching = widget.search.trim().isNotEmpty;
    final hasFilter = _filter != StaffFilter.all;

    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDirectoryToolbar<StaffFilter>(
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            searchHint: S.searchStaffHint,
            filter: _filter,
            allLabel: S.filters,
            options: StaffFilter.values,
            optionLabel: (filter) => filter.label,
            onFilterChanged: _setFilter,
            onClearFilter: _clearFilter,
            filterLabel: S.staffFilter,
            hasActiveFilter: hasFilter,
          ),
          const SizedBox(height: AppSizes.px14),
          Expanded(
            child: filtered.isEmpty
                ? AdminEmptyState(
                    icon: widget.staff.isEmpty || (!searching && !hasFilter)
                        ? AppIcons.userMultiple
                        : AppIcons.userSearch01,
                    message: searching
                        ? S.staffNoMatches
                        : hasFilter
                        ? S.staffEmptyFilter
                        : S.noStaffFound,
                    action: searching || hasFilter
                        ? TextButton(
                            onPressed: _clearAll,
                            child: Text(S.clearFilters),
                          )
                        : null,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 840) {
                        return StaffCards(
                          staff: visible,
                          canManagePermissions: widget.canManagePermissions,
                          onManage: widget.onManage,
                          onEdit: widget.onEdit,
                        );
                      }
                      return StaffTable(
                        staff: visible,
                        canManagePermissions: widget.canManagePermissions,
                        onManage: widget.onManage,
                        onEdit: widget.onEdit,
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
                  S.staffRowsLabel(first, last, count),
              onChanged: (value) => setState(() => _page = value),
            ),
        ],
      ),
    );
  }
}
