import 'package:admin_app/features/customers/domain/entities/admin_customer_metrics.dart';
import 'package:admin_app/features/customers/domain/repositories/customer_repository.dart';

/// قراءة مؤشرات شاشة العملاء.
class LoadCustomerMetricsUseCase {
  const LoadCustomerMetricsUseCase(this._repository);

  final CustomerRepository _repository;

  Future<AdminCustomerMetrics> call() => _repository.loadMetrics();
}
