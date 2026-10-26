import 'package:admin_app/features/audit/data/models/admin_audit_metrics.dart';
import 'package:admin_app/features/audit/domain/repositories/audit_repository.dart';

/// قراءة ملخص مؤشرات التدقيق.
class LoadMetricsUseCase {
  const LoadMetricsUseCase(this._repository);

  final AuditRepository _repository;

  Future<AdminAuditMetrics> call() => _repository.loadMetrics();
}
