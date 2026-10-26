import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';

enum AdminReviewsPageStatus { initial, loading, ready, failure }

class AdminReviewsState {
  const AdminReviewsState({
    this.status = AdminReviewsPageStatus.initial,
    this.reviews = const <AdminReview>[],
    this.metrics = AdminReviewMetrics.empty,
    this.errorMessage,
  });

  final AdminReviewsPageStatus status;
  final List<AdminReview> reviews;
  final AdminReviewMetrics metrics;
  final String? errorMessage;

  bool get isLoading => status == AdminReviewsPageStatus.loading;
  bool get isFailure => status == AdminReviewsPageStatus.failure;
  bool get hasData => reviews.isNotEmpty || metrics.total > 0;

  AdminReviewsState copyWith({
    AdminReviewsPageStatus? status,
    List<AdminReview>? reviews,
    AdminReviewMetrics? metrics,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminReviewsState(
      status: status ?? this.status,
      reviews: reviews ?? this.reviews,
      metrics: metrics ?? this.metrics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
