import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement_metrics.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';

/// قراءة مؤشرات حركات المخزون.
class LoadMovementMetricsUseCase {
  const LoadMovementMetricsUseCase(this._repository);

  final InventoryRepository _repository;

  Future<AdminStockMovementMetrics> call({String? branchId, String? period}) =>
      _repository.loadMovementMetrics(branchId: branchId, period: period);
}
