import 'package:admin_app/features/payments/data/models/admin_payment.dart';
import 'package:admin_app/features/payments/domain/repositories/payment_repository.dart';

/// قراءة كل سجلات المدفوعات.
class LoadPaymentsUseCase {
  const LoadPaymentsUseCase(this._repository);

  final PaymentRepository _repository;

  Future<List<AdminPayment>> call() => _repository.loadPayments();
}
