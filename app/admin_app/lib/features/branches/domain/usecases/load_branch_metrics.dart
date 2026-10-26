import 'package:admin_app/features/branches/domain/entities/admin_branch_metrics.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';

/// قراءة مؤشرات شاشة الفروع.
class LoadBranchMetricsUseCase {
  const LoadBranchMetricsUseCase(this._repository);

  final BranchRepository _repository;

  Future<AdminBranchMetrics> call() => _repository.loadMetrics();
}
