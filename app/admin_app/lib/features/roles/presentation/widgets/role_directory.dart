import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/models/role_filter.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_cards.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_table.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_directory_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class RoleDirectory extends StatefulWidget {
  const RoleDirectory({
    super.key,
    required this.roles,
    required this.search,
    required this.onSearchChanged,
    required this.onManage,
    required this.canManage,
  });

  final List<AdminRole> roles;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminRole>? onManage;
  final bool canManage;

  @override
  State<RoleDirectory> createState() => _RoleDirectoryState();
}

class _RoleDirectoryState extends State<RoleDirectory> {
  static const _pageSize = 8;

  late final TextEditingController _searchController;
  RoleFilter _filter = RoleFilter.all;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(RoleDirectory oldWidget) {
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

  List<AdminRole> get _filtered =>
      filterRoles(widget.roles, search: widget.search, filter: _filter);

  void _onSearchChanged(String value) {
    if (_page != 0) setState(() => _page = 0);
    widget.onSearchChanged(value);
  }

  void _setFilter(RoleFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 0;
    });
  }

  void _clearFilter() {
    if (_filter == RoleFilter.all) return;
    setState(() {
      _filter = RoleFilter.all;
      _page = 0;
    });
  }

  void _clearAll() {
    _searchController.clear();
    widget.onSearchChanged('');
    setState(() {
      _filter = RoleFilter.all;
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
    final hasFilter = _filter != RoleFilter.all;

    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDirectoryToolbar<RoleFilter>(
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            searchHint: S.searchRolesHint,
            filter: _filter,
            allLabel: S.filters,
            options: RoleFilter.values,
            optionLabel: (filter) => filter.label,
            onFilterChanged: _setFilter,
            onClearFilter: _clearFilter,
            filterLabel: S.rolesFilter,
            hasActiveFilter: hasFilter,
          ),
          const SizedBox(height: AppSizes.px14),
          Expanded(
            child: filtered.isEmpty
                ? AdminEmptyState(
                    icon: widget.roles.isEmpty || (!searching && !hasFilter)
                        ? AppIcons.shield01
                        : AppIcons.search01,
                    message: searching
                        ? S.rolesNoMatches
                        : hasFilter
                        ? S.rolesEmptyFilter
                        : S.noRolesFound,
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
                        return RoleCards(
                          roles: visible,
                          onManage: widget.onManage,
                          canManage: widget.canManage,
                        );
                      }
                      return RoleTable(
                        roles: visible,
                        onManage: widget.onManage,
                        canManage: widget.canManage,
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
                  S.rolesRowsLabel(first, last, count),
              onChanged: (value) => setState(() => _page = value),
            ),
        ],
      ),
    );
  }
}
