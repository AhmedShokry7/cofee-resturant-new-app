import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/presentation/models/review_filter.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_cards.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_table.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_directory_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class ReviewDirectory extends StatefulWidget {
  const ReviewDirectory({
    super.key,
    required this.reviews,
    required this.search,
    required this.onSearchChanged,
    required this.canManage,
    required this.ratingFilter,
    required this.onRatingCleared,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  final List<AdminReview> reviews;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool canManage;
  final int? ratingFilter;
  final VoidCallback onRatingCleared;
  final ValueChanged<AdminReview> onOpen;
  final ValueChanged<AdminReview> onToggle;
  final ValueChanged<AdminReview> onDelete;

  @override
  State<ReviewDirectory> createState() => _ReviewDirectoryState();
}

class _ReviewDirectoryState extends State<ReviewDirectory> {
  static const _pageSize = 6;
  static const _cardsBreakpoint = 1120.0;

  late final TextEditingController _searchController;
  AdminReviewFilter _filter = AdminReviewFilter.all;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(ReviewDirectory oldWidget) {
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
    if (oldWidget.ratingFilter != widget.ratingFilter) {
      _page = 0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminReview> get _filtered => filterReviews(
    widget.reviews,
    search: widget.search,
    filter: _filter,
    rating: widget.ratingFilter,
  );

  void _onSearch(String value) {
    widget.onSearchChanged(value);
    setState(() => _page = 0);
  }

  void _setFilter(AdminReviewFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 0;
    });
  }

  void _clearFilter() => setState(() {
    _filter = AdminReviewFilter.all;
    _page = 0;
  });

  void _clearAll() {
    _searchController.clear();
    widget.onSearchChanged('');
    widget.onRatingCleared();
    _clearFilter();
  }

  String _filterLabel(AdminReviewFilter option) {
    final count = option == AdminReviewFilter.all
        ? widget.reviews.length
        : widget.reviews.where(option.matches).length;
    return localizeDigits(S.reviewsFilterOption(option.label, count));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final count = filtered.length;
    final pages = count == 0 ? 0 : (count / _pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final canClear =
        _filter != AdminReviewFilter.all ||
        widget.ratingFilter != null ||
        widget.search.trim().isNotEmpty;
    final visible = filtered
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);

    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDirectoryToolbar<AdminReviewFilter>(
            searchController: _searchController,
            onSearchChanged: _onSearch,
            searchHint: S.searchReviewsHint,
            filter: _filter,
            allLabel: _filterLabel(AdminReviewFilter.all),
            options: AdminReviewFilter.values,
            optionLabel: _filterLabel,
            onFilterChanged: _setFilter,
            onClearFilter: _clearFilter,
            filterLabel: S.reviewsFilter,
            hasActiveFilter: _filter != AdminReviewFilter.all,
          ),
          if (widget.ratingFilter != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _RatingFilterChip(
                rating: widget.ratingFilter!,
                onClear: widget.onRatingCleared,
              ),
            ),
          ],
          const SizedBox(height: 13),
          Expanded(
            child: count == 0
                ? _emptyState(canClear: canClear)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < _cardsBreakpoint) {
                        return ReviewCards(
                          reviews: visible,
                          canManage: widget.canManage,
                          onOpen: widget.onOpen,
                          onToggle: widget.onToggle,
                          onDelete: widget.onDelete,
                        );
                      }
                      return ReviewTable(
                        reviews: visible,
                        canManage: widget.canManage,
                        onOpen: widget.onOpen,
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
              labelBuilder: reviewRowsLabel,
              onChanged: (value) => setState(() => _page = value),
            ),
        ],
      ),
    );
  }

  Widget _emptyState({required bool canClear}) {
    final noData = widget.reviews.isEmpty;
    return AdminEmptyState(
      icon: HugeIcons.strokeRoundedComment01,
      message: noData ? S.reviewsEmpty : S.reviewsNoMatches,
      hint: noData ? S.reviewsEmptyHint : null,
      action: canClear
          ? TextButton(onPressed: _clearAll, child: Text(S.clearFilters))
          : null,
    );
  }
}

class _RatingFilterChip extends StatelessWidget {
  const _RatingFilterChip({required this.rating, required this.onClear});

  final int rating;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = adminFlagForeground(theme, AppColor.adminAccent);
    return Tooltip(
      message: S.reviewsClearRating,
      child: Material(
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onClear,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: AppColor.adminWarning,
                ),
                const SizedBox(width: 5),
                Text(
                  S.reviewsStarsCount(rating),
                  style: TextStyle(
                    color: foreground,
                    fontSize: AppFontSizes.size9_5,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                const SizedBox(width: 5),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 12,
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
