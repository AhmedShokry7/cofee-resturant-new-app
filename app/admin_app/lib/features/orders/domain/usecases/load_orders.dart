import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';

/// قراءة كل طلبات اللوحة.
class LoadOrdersUseCase {
  const LoadOrdersUseCase(this._repository);

  final OrderRepository _repository;

  Future<List<AdminOrder>> call() => _repository.loadOrders();
}
