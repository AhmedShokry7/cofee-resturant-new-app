import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';

/// تحديث حالة دفع الطلب.
class UpdatePaymentStatusUseCase {
  const UpdatePaymentStatusUseCase(this._repository);

  final OrderRepository _repository;

  Future<void> call(String orderId, String paymentStatus) =>
      _repository.updatePaymentStatus(orderId, paymentStatus);
}
