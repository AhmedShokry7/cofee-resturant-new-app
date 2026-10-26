import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';

/// إضافة منتج إلى طلب قائم.
class AddOrderItemUseCase {
  const AddOrderItemUseCase(this._repository);

  final OrderRepository _repository;

  Future<void> call(String orderId, String productId, int quantity) =>
      _repository.addOrderItem(orderId, productId, quantity);
}
