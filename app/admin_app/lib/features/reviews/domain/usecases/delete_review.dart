import 'package:admin_app/features/reviews/domain/repositories/review_repository.dart';

/// حذف مراجعة.
class DeleteReviewUseCase {
  const DeleteReviewUseCase(this._repository);

  final ReviewRepository _repository;

  Future<ReviewMutationOutcome> call(String reviewId) =>
      _repository.deleteReview(reviewId);
}
