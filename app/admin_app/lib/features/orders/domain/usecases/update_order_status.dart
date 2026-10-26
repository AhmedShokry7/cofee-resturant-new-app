import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';

/// تحديث حالة الطلب بعد فحص صلاحيات الموظف في القاعدة.
class UpdateOrderStatusUseCase {
  const UpdateOrderStatusUseCase(this._repository);

  final OrderRepository _repository;

  Future<void> call(String orderId, String status) =>
      _repository.updateOrderStatus(orderId, status);
}
