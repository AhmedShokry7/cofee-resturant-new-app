import 'package:admin_app/features/reviews/data/repositories/admin_reviews_repository.dart';
import 'package:admin_app/features/reviews/domain/repositories/review_repository.dart';

/// نقطة تركيب اعتمادات فيتشر المراجعات داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class ReviewsDependencies {
  ReviewsDependencies._();

  static ReviewRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static ReviewRepository get repository =>
      _repository ??= AdminReviewsRepository();
}
