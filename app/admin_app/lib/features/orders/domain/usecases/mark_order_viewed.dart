import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';

/// وسم الطلب بأنه قرأه موظف بعد فحص صلاحياته في القاعدة.
class MarkOrderViewedUseCase {
  const MarkOrderViewedUseCase(this._repository);

  final OrderRepository _repository;

  Future<void> call(String orderId) => _repository.markOrderViewed(orderId);
}
