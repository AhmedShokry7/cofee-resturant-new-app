import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/domain/repositories/review_repository.dart';

/// قراءة كل المراجعات.
class LoadReviewsUseCase {
  const LoadReviewsUseCase(this._repository);

  final ReviewRepository _repository;

  Future<List<AdminReview>> call() => _repository.loadReviews();
}
