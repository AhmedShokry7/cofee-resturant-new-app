import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';

/// حذف سطر من سطور الطلب.
class RemoveOrderItemUseCase {
  const RemoveOrderItemUseCase(this._repository);

  final OrderRepository _repository;

  Future<void> call(String orderItemId) =>
      _repository.removeOrderItem(orderItemId);
}
