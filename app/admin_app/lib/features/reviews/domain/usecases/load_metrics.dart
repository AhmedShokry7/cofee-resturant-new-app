import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';
import 'package:admin_app/features/reviews/domain/repositories/review_repository.dart';

/// قراءة ملخص مؤشرات المراجعات.
class LoadMetricsUseCase {
  const LoadMetricsUseCase(this._repository);

  final ReviewRepository _repository;

  Future<AdminReviewMetrics> call() => _repository.loadMetrics();
}
