import 'package:admin_app/features/reviews/domain/repositories/review_repository.dart';

/// نشر المراجعة أو إخفاؤها.
class SetPublishedUseCase {
  const SetPublishedUseCase(this._repository);

  final ReviewRepository _repository;

  Future<ReviewMutationOutcome> call(String reviewId, bool published) =>
      _repository.setPublished(reviewId, published);
}
