import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/models/subscription_plan_filter.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/subscription_plan_cards.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/subscription_plan_table.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_directory_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class SubscriptionPlanDirectory extends StatefulWidget {
  const SubscriptionPlanDirectory({
    super.key,
    required this.plans,
    required this.search,
    required this.onSearchChanged,
    required this.onEdit,
    required this.onAdd,
  });

  final List<AdminSubscriptionPlan> plans;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminSubscriptionPlan> onEdit;
  final VoidCallback onAdd;

  @override
  State<SubscriptionPlanDirectory> createState() =>
      _SubscriptionPlanDirectoryState();
}

class _SubscriptionPlanDirectoryState extends State<SubscriptionPlanDirectory> {
  static const _pageSize = 8;

  late final TextEditingController _searchController;
  SubscriptionPlanFilter _filter = SubscriptionPlanFilter.all;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(SubscriptionPlanDirectory oldWidget) {
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

  List<AdminSubscriptionPlan> get _filtered => filterSubscriptionPlans(
    widget.plans,
    search: widget.search,
    filter: _filter,
  );

  void _setFilter(SubscriptionPlanFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 0;
    });
  }

  void _clearFilter() {
    if (_filter == SubscriptionPlanFilter.all) return;
    setState(() {
      _filter = SubscriptionPlanFilter.all;
      _page = 0;
    });
  }

  void _clearAll() {
    _searchController.clear();
    widget.onSearchChanged('');
    setState(() {
      _filter = SubscriptionPlanFilter.all;
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
    final hasAny = widget.plans.isNotEmpty;
    final canClear =
        _filter != SubscriptionPlanFilter.all ||
        widget.search.trim().isNotEmpty;

    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDirectoryToolbar<SubscriptionPlanFilter>(
            searchController: _searchController,
            onSearchChanged: (value) {
              widget.onSearchChanged(value);
              setState(() => _page = 0);
            },
            searchHint: S.searchSubscriptionPlansHint,
            filter: _filter,
            allLabel: S.subscriptionPlansFilterAll,
            options: SubscriptionPlanFilter.values,
            optionLabel: (option) => option.label,
            onFilterChanged: _setFilter,
            onClearFilter: _clearFilter,
            filterLabel: S.subscriptionPlansFilter,
            hasActiveFilter: _filter != SubscriptionPlanFilter.all,
          ),
          const SizedBox(height: AppSizes.px14),
          Expanded(
            child: filtered.isEmpty
                ? AdminEmptyState(
                    icon: hasAny ? AppIcons.search01 : AppIcons.package,
                    message: hasAny
                        ? S.subscriptionPlansNoMatches
                        : S.noSubscriptionPlans,
                    action: canClear
                        ? TextButton(
                            onPressed: _clearAll,
                            child: Text(S.clearFilters),
                          )
                        : hasAny
                        ? null
                        : TextButton.icon(
                            onPressed: widget.onAdd,
                            icon: const Icon(AppIcons.add01, size: 16),
                            label: Text(S.subscriptionPlanAddAction),
                          ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 840) {
                        return SubscriptionPlanCards(
                          plans: visible,
                          onEdit: widget.onEdit,
                        );
                      }
                      return SubscriptionPlanTable(
                        plans: visible,
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
                  S.subscriptionPlansRowsLabel(first, last, count),
              onChanged: (value) => setState(() => _page = value),
            ),
        ],
      ),
    );
  }
}
