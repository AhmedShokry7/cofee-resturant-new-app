import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/repositories/dashboard_repository.dart';

/// قراءة ملخص أرقام لوحة التحكم.
class LoadDashboardMetricsUseCase {
  const LoadDashboardMetricsUseCase(this._repository);

  final DashboardRepository _repository;

  Future<AdminDashboardMetrics> call() => _repository.loadMetrics();
}
