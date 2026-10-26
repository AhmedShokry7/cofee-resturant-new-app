import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';
import 'package:admin_app/features/reviews/data/repositories/admin_reviews_repository.dart';
import 'package:admin_app/features/reviews/presentation/manager/admin_reviews_state.dart';

class AdminReviewsCubit extends Cubit<AdminReviewsState> {
  AdminReviewsCubit({AdminReviewsRepository? repository})
    : _repository = repository ?? AdminReviewsRepository(),
      super(const AdminReviewsState());

  final AdminReviewsRepository _repository;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(
      state.copyWith(status: AdminReviewsPageStatus.loading, clearError: true),
    );
    try {
      final results = await Future.wait<Object>([
        _repository.loadReviews(),
        _repository.loadMetrics(),
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
    final outcome = await _repository.setPublished(reviewId, published);
    if (outcome == ReviewMutationOutcome.success) await load();
    return outcome;
  }

  Future<ReviewMutationOutcome> deleteReview(String reviewId) async {
    final outcome = await _repository.deleteReview(reviewId);
    if (outcome == ReviewMutationOutcome.success) await load();
    return outcome;
  }
}
