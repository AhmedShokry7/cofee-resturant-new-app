import 'package:admin_app/features/customers/data/models/admin_customer.dart';

enum AdminCustomerStatus { initial, loading, ready, failure }

class AdminCustomerState {
  const AdminCustomerState({
    this.status = AdminCustomerStatus.initial,
    this.customers = const <AdminCustomer>[],
    this.errorMessage,
  });

  final AdminCustomerStatus status;
  final List<AdminCustomer> customers;
  final String? errorMessage;

  bool get isLoading => status == AdminCustomerStatus.loading;
  bool get hasCustomers => customers.isNotEmpty;

  AdminCustomerState copyWith({
    AdminCustomerStatus? status,
    List<AdminCustomer>? customers,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminCustomerState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
