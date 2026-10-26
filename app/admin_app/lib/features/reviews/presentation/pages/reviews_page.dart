import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/domain/repositories/review_repository.dart';
import 'package:admin_app/features/reviews/presentation/manager/admin_reviews_cubit.dart';
import 'package:admin_app/features/reviews/presentation/manager/admin_reviews_state.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_details_dialog.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_directory.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_page_body.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({
    super.key,
    required this.searchController,
    this.canManage = false,
    this.cubit,
  });

  static const String routeName = '/reviews';

  final AdminSearchController searchController;
  final bool canManage;
  final AdminReviewsCubit? cubit;

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  late final AdminReviewsCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';
  int? _ratingFilter;
  final Set<String> _pendingReviews = <String>{};

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminReviewsCubit();
    if (_ownsCubit) _load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query.trim());
  }

  Future<void> _load() async {
    await _cubit.load();
  }

  Future<void> _openDetails(AdminReview review) async {
    final action = await showReviewDetailsDialog(
      context: context,
      review: review,
      canManage: widget.canManage,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ReviewDetailsAction.togglePublished:
        await _toggle(review);
      case ReviewDetailsAction.delete:
        await _delete(review);
    }
  }

  Future<void> _toggle(AdminReview review) async {
    if (_pendingReviews.contains(review.id)) return;
    _pendingReviews.add(review.id);
    try {
      final outcome = await _cubit.setPublished(review.id, !review.isPublished);
      if (!mounted) return;
      final name = reviewCustomerName(review);
      switch (outcome) {
        case ReviewMutationOutcome.success:
          _showMessage(
            review.isPublished
                ? S.reviewsHiddenToast(name)
                : S.reviewsPublishedToast(name),
          );
        case ReviewMutationOutcome.notFound:
          _showMessage(S.reviewsNotFound, error: true);
        case ReviewMutationOutcome.failed:
          _showMessage(S.reviewsToggleFailed, error: true);
      }
    } finally {
      _pendingReviews.remove(review.id);
    }
  }

  Future<void> _delete(AdminReview review) async {
    if (_pendingReviews.contains(review.id)) return;
    final confirmed = await _confirmDelete(review);
    if (confirmed != true || !mounted) return;
    _pendingReviews.add(review.id);
    try {
      final outcome = await _cubit.deleteReview(review.id);
      if (!mounted) return;
      switch (outcome) {
        case ReviewMutationOutcome.success:
          _showMessage(S.reviewsDeletedToast(reviewCustomerName(review)));
        case ReviewMutationOutcome.notFound:
          _showMessage(S.reviewsNotFound, error: true);
        case ReviewMutationOutcome.failed:
          _showMessage(S.reviewsDeleteFailed, error: true);
      }
    } finally {
      _pendingReviews.remove(review.id);
    }
  }

  Future<bool?> _confirmDelete(AdminReview review) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Text(
            S.reviewsDeleteTitle,
            style: TextStyle(
              fontSize: AppFontSizes.size15,
              fontWeight: AppFontWeights.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            S.reviewsDeleteMessage(reviewCustomerName(review)),
            style: const TextStyle(
              fontSize: AppFontSizes.size11_5,
              height: AppTextHeights.line1_6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(S.cancel),
            ),
            FilledButton(
              key: const Key('review-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColor.errorColor,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(
                S.reviewsDeleteConfirm,
                style: const TextStyle(
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColor.errorColor : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminReviewsCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminReviewsCubit, AdminReviewsState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const AdminLoadingView();
          }
          if (state.isFailure && !state.hasData) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _load,
            );
          }
          return ReviewPageBody(
            metrics: state.metrics,
            canManage: widget.canManage,
            selectedRating: _ratingFilter,
            onRatingSelected: (rating) =>
                setState(() => _ratingFilter = rating),
            errorMessage: state.isFailure ? state.errorMessage : null,
            onRefresh: _load,
            directory: ReviewDirectory(
              reviews: state.reviews,
              search: _searchQuery,
              onSearchChanged: widget.searchController.update,
              canManage: widget.canManage,
              ratingFilter: _ratingFilter,
              onRatingCleared: () => setState(() => _ratingFilter = null),
              onOpen: _openDetails,
              onToggle: _toggle,
              onDelete: _delete,
            ),
          );
        },
      ),
    );
  }
}
