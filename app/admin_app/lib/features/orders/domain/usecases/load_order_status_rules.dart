import 'package:admin_app/features/orders/domain/entities/order_status_rules.dart';
import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';

/// قراءة مصفوفة حالات الطلب المسموحة لصاحب الجلسة.
class LoadOrderStatusRulesUseCase {
  const LoadOrderStatusRulesUseCase(this._repository);

  final OrderRepository _repository;

  Future<OrderStatusRules?> call() => _repository.loadStatusRules();
}
