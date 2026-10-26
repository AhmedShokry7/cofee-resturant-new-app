import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer_metrics.dart';

enum AdminCustomerStatus { initial, loading, ready, failure }

class AdminCustomerState {
  const AdminCustomerState({
    this.status = AdminCustomerStatus.initial,
    this.customers = const <AdminCustomer>[],
    this.metrics = AdminCustomerMetrics.empty,
    this.errorMessage,
  });

  final AdminCustomerStatus status;
  final List<AdminCustomer> customers;
  final AdminCustomerMetrics metrics;
  final String? errorMessage;

  bool get isLoading => status == AdminCustomerStatus.loading;
  bool get hasCustomers => customers.isNotEmpty;

  AdminCustomerState copyWith({
    AdminCustomerStatus? status,
    List<AdminCustomer>? customers,
    AdminCustomerMetrics? metrics,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminCustomerState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      metrics: metrics ?? this.metrics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
