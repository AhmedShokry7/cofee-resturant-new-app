import 'package:admin_app/features/inventory/domain/entities/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';

/// قراءة مؤشرات المخزون.
class LoadInventoryMetricsUseCase {
  const LoadInventoryMetricsUseCase(this._repository);

  final InventoryRepository _repository;

  Future<AdminInventoryMetrics> call({String? branchId}) =>
      _repository.loadMetrics(branchId: branchId);
}
