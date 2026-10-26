import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/models/subscription_filter.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_cards.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_table.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_directory_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class SubscriptionDirectory extends StatefulWidget {
  const SubscriptionDirectory({
    super.key,
    required this.subscriptions,
    required this.search,
    required this.onSearchChanged,
    required this.onOpen,
  });

  final List<AdminSubscription> subscriptions;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminSubscription> onOpen;

  @override
  State<SubscriptionDirectory> createState() => _SubscriptionDirectoryState();
}

class _SubscriptionDirectoryState extends State<SubscriptionDirectory> {
  static const _pageSize = 8;

  late final TextEditingController _searchController;
  SubscriptionFilter _filter = SubscriptionFilter.all;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(SubscriptionDirectory oldWidget) {
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

  List<AdminSubscription> get _filtered => filterSubscriptions(
    widget.subscriptions,
    search: widget.search,
    filter: _filter,
  );

  void _setFilter(SubscriptionFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 0;
    });
  }

  void _clearFilter() {
    if (_filter == SubscriptionFilter.all) return;
    setState(() {
      _filter = SubscriptionFilter.all;
      _page = 0;
    });
  }

  void _clearAll() {
    _searchController.clear();
    widget.onSearchChanged('');
    setState(() {
      _filter = SubscriptionFilter.all;
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
    final hasAny = widget.subscriptions.isNotEmpty;
    final canClear =
        _filter != SubscriptionFilter.all || widget.search.trim().isNotEmpty;

    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDirectoryToolbar<SubscriptionFilter>(
            searchController: _searchController,
            onSearchChanged: (value) {
              widget.onSearchChanged(value);
              setState(() => _page = 0);
            },
            searchHint: S.searchSubscriptionsHint,
            filter: _filter,
            allLabel: S.subscriptionsFilterAll,
            options: SubscriptionFilter.values,
            optionLabel: (option) => option.label,
            onFilterChanged: _setFilter,
            onClearFilter: _clearFilter,
            filterLabel: S.subscriptionsFilter,
            hasActiveFilter: _filter != SubscriptionFilter.all,
          ),
          const SizedBox(height: AppSizes.px14),
          Expanded(
            child: filtered.isEmpty
                ? AdminEmptyState(
                    icon: hasAny ? AppIcons.search01 : AppIcons.repeat,
                    message: hasAny
                        ? S.subscriptionsNoMatches
                        : S.noSubscriptions,
                    action: canClear
                        ? TextButton(
                            onPressed: _clearAll,
                            child: Text(S.clearFilters),
                          )
                        : null,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 840) {
                        return SubscriptionCards(
                          subscriptions: visible,
                          onOpen: widget.onOpen,
                        );
                      }
                      return SubscriptionTable(
                        subscriptions: visible,
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
                  S.subscriptionsRowsLabel(first, last, count),
              onChanged: (value) => setState(() => _page = value),
            ),
        ],
      ),
    );
  }
}
