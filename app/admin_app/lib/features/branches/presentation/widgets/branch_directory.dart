import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/branches/presentation/models/branch_filter.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_cards.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_table.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_directory_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class BranchDirectory extends StatefulWidget {
  const BranchDirectory({
    super.key,
    required this.branches,
    required this.search,
    required this.onSearchChanged,
    required this.canManage,
    required this.canManagePricing,
    required this.onAdd,
    required this.onEdit,
    required this.onChangeImage,
    required this.onManageDelivery,
    required this.onToggleActive,
    required this.onDelete,
    this.onManagePricing,
  });

  final List<AdminBranch> branches;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool canManage;
  final bool canManagePricing;
  final VoidCallback onAdd;
  final ValueChanged<AdminBranch> onEdit;
  final ValueChanged<AdminBranch> onChangeImage;
  final ValueChanged<AdminBranch> onManageDelivery;
  final ValueChanged<AdminBranch>? onManagePricing;
  final ValueChanged<AdminBranch> onToggleActive;
  final ValueChanged<AdminBranch> onDelete;

  @override
  State<BranchDirectory> createState() => _BranchDirectoryState();
}

class _BranchDirectoryState extends State<BranchDirectory> {
  static const _pageSize = 5;
  static const _cardsBreakpoint = 980.0;

  late final TextEditingController _searchController;
  BranchFilter _filter = BranchFilter.all;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(BranchDirectory oldWidget) {
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

  List<AdminBranch> get _filtered =>
      filterBranches(widget.branches, search: widget.search, filter: _filter);

  void _onSearch(String value) {
    widget.onSearchChanged(value);
    setState(() => _page = 0);
  }

  void _setFilter(BranchFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 0;
    });
  }

  void _clearFilter() {
    if (_filter == BranchFilter.all) return;
    setState(() {
      _filter = BranchFilter.all;
      _page = 0;
    });
  }

  void _clearAll() {
    _searchController.clear();
    widget.onSearchChanged('');
    setState(() {
      _filter = BranchFilter.all;
      _page = 0;
    });
  }

  String _filterLabel(BranchFilter option) {
    final count = option == BranchFilter.all
        ? widget.branches.length
        : widget.branches.where(option.matches).length;
    return localizeDigits(S.branchesFilterOption(option.label, count));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final count = filtered.length;
    final pages = count == 0 ? 0 : (count / _pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final visible = filtered
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    final setupCount = widget.branches
        .where((branch) => branch.needsSetup)
        .length;
    final canClear =
        _filter != BranchFilter.all || widget.search.trim().isNotEmpty;

    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDirectoryToolbar<BranchFilter>(
            searchController: _searchController,
            onSearchChanged: _onSearch,
            searchHint: S.searchBranchesHint,
            filter: _filter,
            allLabel: _filterLabel(BranchFilter.all),
            options: BranchFilter.values,
            optionLabel: _filterLabel,
            onFilterChanged: _setFilter,
            onClearFilter: _clearFilter,
            filterLabel: S.branchesFilterLabel,
            hasActiveFilter: _filter != BranchFilter.all,
          ),
          if (setupCount > 0 && _filter != BranchFilter.needsSetup)
            _SetupBanner(
              count: setupCount,
              onReview: () => _setFilter(BranchFilter.needsSetup),
            ),
          const SizedBox(height: 13),
          Expanded(
            child: count == 0
                ? _emptyState(canClear: canClear)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < _cardsBreakpoint) {
                        return BranchCards(
                          branches: visible,
                          canManage: widget.canManage,
                          canManagePricing: widget.canManagePricing,
                          onEdit: widget.onEdit,
                          onChangeImage: widget.onChangeImage,
                          onManageDelivery: widget.onManageDelivery,
                          onManagePricing: widget.onManagePricing,
                          onToggleActive: widget.onToggleActive,
                          onDelete: widget.onDelete,
                        );
                      }
                      return BranchTable(
                        branches: visible,
                        canManage: widget.canManage,
                        canManagePricing: widget.canManagePricing,
                        onEdit: widget.onEdit,
                        onChangeImage: widget.onChangeImage,
                        onManageDelivery: widget.onManageDelivery,
                        onManagePricing: widget.onManagePricing,
                        onToggleActive: widget.onToggleActive,
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
              labelBuilder: S.branchesRowsLabel,
              onChanged: (value) => setState(() => _page = value),
            ),
        ],
      ),
    );
  }

  Widget _emptyState({required bool canClear}) {
    final noData = widget.branches.isEmpty;
    return AdminEmptyState(
      icon: HugeIcons.strokeRoundedStore01,
      message: noData ? S.noBranchesFound : S.branchesNoMatches,
      hint: noData ? S.branchesEmptyHint : S.branchesNoMatchesHint,
      action: canClear
          ? TextButton(onPressed: _clearAll, child: Text(S.clearFilters))
          : noData && widget.canManage
          ? TextButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(HugeIcons.strokeRoundedAdd01, size: 16),
              label: Text(S.addBranch),
            )
          : null,
    );
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.count, required this.onReview});

  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final foreground = adminFlagForeground(theme, AppColor.adminWarning);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 6, 7),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminWarning,
          AppColor.adminWarningSurface,
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppColor.adminWarning.withValues(alpha: dark ? .35 : .18),
        ),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlertCircle,
            size: 16,
            color: foreground,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.branchesNeedsSetupTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: AppFontSizes.size10,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                Text(
                  localizeDigits(S.branchesNeedsSetupBanner(count)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground.withValues(alpha: .85),
                    fontSize: AppFontSizes.size9,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onReview,
            style: TextButton.styleFrom(
              foregroundColor: foreground,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              S.branchesSetupAction,
              style: const TextStyle(
                fontSize: AppFontSizes.size9_5,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
