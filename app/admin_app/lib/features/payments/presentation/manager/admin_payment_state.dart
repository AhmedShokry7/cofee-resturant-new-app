import 'package:admin_app/features/payments/data/models/admin_payment.dart';

enum AdminPaymentStatus { initial, loading, ready, failure }

class AdminPaymentState {
  const AdminPaymentState({
    this.status = AdminPaymentStatus.initial,
    this.payments = const <AdminPayment>[],
    this.errorMessage,
  });

  final AdminPaymentStatus status;
  final List<AdminPayment> payments;
  final String? errorMessage;

  bool get isLoading => status == AdminPaymentStatus.loading;
  bool get hasPayments => payments.isNotEmpty;

  AdminPaymentState copyWith({
    AdminPaymentStatus? status,
    List<AdminPayment>? payments,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminPaymentState(
      status: status ?? this.status,
      payments: payments ?? this.payments,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
