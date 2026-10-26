import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';
import 'package:admin_app/features/reviews/di/reviews_dependencies.dart';
import 'package:admin_app/features/reviews/domain/repositories/review_repository.dart';
import 'package:admin_app/features/reviews/domain/usecases/delete_review.dart';
import 'package:admin_app/features/reviews/domain/usecases/load_metrics.dart';
import 'package:admin_app/features/reviews/domain/usecases/load_reviews.dart';
import 'package:admin_app/features/reviews/domain/usecases/set_published.dart';
import 'package:admin_app/features/reviews/presentation/manager/admin_reviews_state.dart';

class AdminReviewsCubit extends Cubit<AdminReviewsState> {
  AdminReviewsCubit({ReviewRepository? repository})
    : this._withUseCases(repository ?? ReviewsDependencies.repository);

  AdminReviewsCubit._withUseCases(ReviewRepository repository)
    : _loadReviews = LoadReviewsUseCase(repository),
      _loadMetrics = LoadMetricsUseCase(repository),
      _setPublished = SetPublishedUseCase(repository),
      _deleteReview = DeleteReviewUseCase(repository),
      super(const AdminReviewsState());

  final LoadReviewsUseCase _loadReviews;
  final LoadMetricsUseCase _loadMetrics;
  final SetPublishedUseCase _setPublished;
  final DeleteReviewUseCase _deleteReview;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(
      state.copyWith(status: AdminReviewsPageStatus.loading, clearError: true),
    );
    try {
      final results = await Future.wait<Object>([
        _loadReviews(),
        _loadMetrics(),
      ]);
      emit(
        state.copyWith(
          status: AdminReviewsPageStatus.ready,
          reviews: results[0] as List<AdminReview>,
          metrics: results[1] as AdminReviewMetrics,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminReviewsPageStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<ReviewMutationOutcome> setPublished(
    String reviewId,
    bool published,
  ) async {
    final outcome = await _setPublished(reviewId, published);
    if (outcome == ReviewMutationOutcome.success) await load();
    return outcome;
  }

  Future<ReviewMutationOutcome> deleteReview(String reviewId) async {
    final outcome = await _deleteReview(reviewId);
    if (outcome == ReviewMutationOutcome.success) await load();
    return outcome;
  }
}
