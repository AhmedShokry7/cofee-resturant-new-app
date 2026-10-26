import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_transaction.dart';
import 'package:admin_app/features/loyalty/presentation/models/loyalty_filters.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_activity_cards.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_activity_table.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_member_cards.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_member_table.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_reward_cards.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_directory_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class LoyaltyDirectory extends StatefulWidget {
  const LoyaltyDirectory({
    super.key,
    required this.rewards,
    required this.members,
    required this.transactions,
    required this.transactionsTotal,
    required this.search,
    required this.onSearchChanged,
    required this.canManage,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<AdminLoyaltyReward> rewards;
  final List<AdminLoyaltyMember> members;
  final List<AdminLoyaltyTransaction> transactions;
  final int transactionsTotal;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool canManage;
  final VoidCallback onAdd;
  final ValueChanged<AdminLoyaltyReward> onEdit;
  final ValueChanged<AdminLoyaltyReward> onToggle;
  final ValueChanged<AdminLoyaltyReward> onDelete;

  @override
  State<LoyaltyDirectory> createState() => _LoyaltyDirectoryState();
}

class _LoyaltyDirectoryState extends State<LoyaltyDirectory> {
  static const _rewardPageSize = 10;
  static const _memberPageSize = 8;
  static const _activityPageSize = 10;

  late final TextEditingController _searchController;
  LoyaltyTab _tab = LoyaltyTab.rewards;
  LoyaltyRewardFilter _rewardFilter = LoyaltyRewardFilter.all;
  LoyaltyMemberFilter _memberFilter = LoyaltyMemberFilter.all;
  LoyaltyActivityFilter _activityFilter = LoyaltyActivityFilter.all;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(LoyaltyDirectory oldWidget) {
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

  int get _pageSize => switch (_tab) {
    LoyaltyTab.rewards => _rewardPageSize,
    LoyaltyTab.members => _memberPageSize,
    LoyaltyTab.activity => _activityPageSize,
  };

  bool get _hasActiveFilter => switch (_tab) {
    LoyaltyTab.rewards => _rewardFilter != LoyaltyRewardFilter.all,
    LoyaltyTab.members => _memberFilter != LoyaltyMemberFilter.all,
    LoyaltyTab.activity => _activityFilter != LoyaltyActivityFilter.all,
  };

  List<AdminLoyaltyReward> get _filteredRewards => filterLoyaltyRewards(
    widget.rewards,
    search: widget.search,
    filter: _rewardFilter,
  );

  List<AdminLoyaltyMember> get _filteredMembers => filterLoyaltyMembers(
    widget.members,
    search: widget.search,
    filter: _memberFilter,
  );

  List<AdminLoyaltyTransaction> get _filteredTransactions =>
      filterLoyaltyTransactions(
        widget.transactions,
        search: widget.search,
        filter: _activityFilter,
      );

  int get _filteredCount => switch (_tab) {
    LoyaltyTab.rewards => _filteredRewards.length,
    LoyaltyTab.members => _filteredMembers.length,
    LoyaltyTab.activity => _filteredTransactions.length,
  };

  bool get _hasAnyData => switch (_tab) {
    LoyaltyTab.rewards => widget.rewards.isNotEmpty,
    LoyaltyTab.members => widget.members.isNotEmpty,
    LoyaltyTab.activity => widget.transactions.isNotEmpty,
  };

  void _setTab(LoyaltyTab tab) {
    if (_tab == tab) return;
    _searchController.clear();
    widget.onSearchChanged('');
    setState(() {
      _tab = tab;
      _page = 0;
    });
  }

  void _setRewardFilter(LoyaltyRewardFilter filter) {
    if (_rewardFilter == filter) return;
    setState(() {
      _rewardFilter = filter;
      _page = 0;
    });
  }

  void _setMemberFilter(LoyaltyMemberFilter filter) {
    if (_memberFilter == filter) return;
    setState(() {
      _memberFilter = filter;
      _page = 0;
    });
  }

  void _setActivityFilter(LoyaltyActivityFilter filter) {
    if (_activityFilter == filter) return;
    setState(() {
      _activityFilter = filter;
      _page = 0;
    });
  }

  void _clearFilters() {
    setState(() {
      _rewardFilter = LoyaltyRewardFilter.all;
      _memberFilter = LoyaltyMemberFilter.all;
      _activityFilter = LoyaltyActivityFilter.all;
      _page = 0;
    });
  }

  void _clearAll() {
    _searchController.clear();
    widget.onSearchChanged('');
    _clearFilters();
  }

  String get _searchHint => switch (_tab) {
    LoyaltyTab.rewards => S.loyaltyRewardsSearchHint,
    LoyaltyTab.members => S.loyaltyMembersSearchHint,
    LoyaltyTab.activity => S.loyaltyActivitySearchHint,
  };

  @override
  Widget build(BuildContext context) {
    final count = _filteredCount;
    final pages = count == 0 ? 0 : (count / _pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final canClear = _hasActiveFilter || widget.search.trim().isNotEmpty;

    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LoyaltyTabs(
            tab: _tab,
            rewardsCount: widget.rewards.length,
            membersCount: widget.members.length,
            activityCount: widget.transactionsTotal,
            onChanged: _setTab,
          ),
          const SizedBox(height: 12),
          _toolbar(),
          const SizedBox(height: 13),
          if (_tab == LoyaltyTab.activity &&
              widget.transactionsTotal > widget.transactions.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActivityWindowNote(
                shown: widget.transactions.length,
                total: widget.transactionsTotal,
              ),
            ),
          Expanded(
            child: count == 0
                ? _emptyState(canClear: canClear)
                : switch (_tab) {
                    LoyaltyTab.rewards => _rewards(page),
                    LoyaltyTab.members => _members(page),
                    LoyaltyTab.activity => _activity(page),
                  },
          ),
          if (count > 0)
            AdminPagination(
              page: page,
              pages: pages,
              count: count,
              pageSize: _pageSize,
              labelBuilder: _rowsLabel,
              onChanged: (value) => setState(() => _page = value),
            ),
        ],
      ),
    );
  }

  Widget _toolbar() => switch (_tab) {
    LoyaltyTab.rewards => AdminDirectoryToolbar<LoyaltyRewardFilter>(
      searchController: _searchController,
      onSearchChanged: _onSearch,
      searchHint: _searchHint,
      filter: _rewardFilter,
      allLabel: S.loyaltyRewardFilterAll,
      options: LoyaltyRewardFilter.values,
      optionLabel: (option) => option.label,
      onFilterChanged: _setRewardFilter,
      onClearFilter: _clearFilters,
      filterLabel: S.loyaltyRewardFilter,
      hasActiveFilter: _rewardFilter != LoyaltyRewardFilter.all,
    ),
    LoyaltyTab.members => AdminDirectoryToolbar<LoyaltyMemberFilter>(
      searchController: _searchController,
      onSearchChanged: _onSearch,
      searchHint: _searchHint,
      filter: _memberFilter,
      allLabel: S.loyaltyMemberFilterAll,
      options: LoyaltyMemberFilter.values,
      optionLabel: (option) => option.label,
      onFilterChanged: _setMemberFilter,
      onClearFilter: _clearFilters,
      filterLabel: S.loyaltyMemberFilter,
      hasActiveFilter: _memberFilter != LoyaltyMemberFilter.all,
    ),
    LoyaltyTab.activity => AdminDirectoryToolbar<LoyaltyActivityFilter>(
      searchController: _searchController,
      onSearchChanged: _onSearch,
      searchHint: _searchHint,
      filter: _activityFilter,
      allLabel: S.loyaltyActivityFilterAll,
      options: LoyaltyActivityFilter.values,
      optionLabel: (option) => option.label,
      onFilterChanged: _setActivityFilter,
      onClearFilter: _clearFilters,
      filterLabel: S.loyaltyActivityFilter,
      hasActiveFilter: _activityFilter != LoyaltyActivityFilter.all,
    ),
  };

  void _onSearch(String value) {
    widget.onSearchChanged(value);
    setState(() => _page = 0);
  }

  Widget _rewards(int page) => LoyaltyRewardGrid(
    rewards: _filteredRewards
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList(growable: false),
    canManage: widget.canManage,
    onEdit: widget.onEdit,
    onToggle: widget.onToggle,
    onDelete: widget.onDelete,
  );

  Widget _members(int page) {
    final visible = _filteredMembers
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return LoyaltyMemberCards(members: visible);
        }
        return LoyaltyMemberTable(members: visible);
      },
    );
  }

  Widget _activity(int page) {
    final visible = _filteredTransactions
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return LoyaltyActivityCards(transactions: visible);
        }
        return LoyaltyActivityTable(transactions: visible);
      },
    );
  }

  Widget _emptyState({required bool canClear}) {
    final (icon, message, showAdd) = switch (_tab) {
      LoyaltyTab.rewards => (
        HugeIcons.strokeRoundedGift,
        _hasAnyData ? S.loyaltyNoRewardsMatches : S.loyaltyNoRewards,
        !_hasAnyData,
      ),
      LoyaltyTab.members => (
        HugeIcons.strokeRoundedUserMultiple,
        _hasAnyData ? S.loyaltyNoMembersMatches : S.loyaltyNoMembers,
        false,
      ),
      LoyaltyTab.activity => (
        HugeIcons.strokeRoundedClock01,
        _hasAnyData ? S.loyaltyNoActivityMatches : S.loyaltyNoActivity,
        false,
      ),
    };
    return AdminEmptyState(
      icon: icon,
      message: message,
      action: canClear
          ? TextButton(onPressed: _clearAll, child: Text(S.clearFilters))
          : showAdd && widget.canManage
          ? TextButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(HugeIcons.strokeRoundedAdd01, size: 16),
              label: Text(S.loyaltyAddReward),
            )
          : null,
    );
  }

  String _rowsLabel(int first, int last, int count) => switch (_tab) {
    LoyaltyTab.rewards => S.loyaltyRowsRewards(first, last, count),
    LoyaltyTab.members => S.loyaltyRowsMembers(first, last, count),
    LoyaltyTab.activity => S.loyaltyRowsActivity(first, last, count),
  };
}

class _LoyaltyTabs extends StatelessWidget {
  const _LoyaltyTabs({
    required this.tab,
    required this.rewardsCount,
    required this.membersCount,
    required this.activityCount,
    required this.onChanged,
  });

  final LoyaltyTab tab;
  final int rewardsCount;
  final int membersCount;
  final int activityCount;
  final ValueChanged<LoyaltyTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: adminTintedSurfaceColor(theme),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: adminCardBorderColor(theme)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tabButton(theme, LoyaltyTab.rewards, rewardsCount),
            _tabButton(theme, LoyaltyTab.members, membersCount),
            _tabButton(theme, LoyaltyTab.activity, activityCount),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(ThemeData theme, LoyaltyTab value, int count) {
    final selected = tab == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 29),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? theme.colorScheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? adminCardBorderColor(theme)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected
                        ? AppColor.adminAccent
                        : adminBodyColor(theme),
                    fontSize: AppFontSizes.size10_5,
                    fontWeight: selected
                        ? AppFontWeights.bold
                        : AppFontWeights.medium,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? adminFlagBackground(
                            theme,
                            AppColor.adminAccent,
                            AppColor.adminAccentSurface,
                          )
                        : adminTintedSurfaceColor(theme),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    loyaltyCount(count),
                    style: TextStyle(
                      color: selected
                          ? adminFlagForeground(theme, AppColor.adminAccent)
                          : adminMutedColor(theme),
                      fontSize: AppFontSizes.size8_5,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityWindowNote extends StatelessWidget {
  const _ActivityWindowNote({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 14,
            color: adminMutedColor(theme),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              localizeDigits(S.loyaltyActivityShowingNewest(shown, total)),
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
