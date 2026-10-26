import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';

/// قراءة صفحة حركات المخزون.
class LoadMovementsUseCase {
  const LoadMovementsUseCase(this._repository);

  final InventoryRepository _repository;

  Future<AdminStockMovementPage> call({
    String? search,
    String? type,
    String? period,
    String? branchId,
    int page = 0,
    int pageSize = 10,
  }) => _repository.loadMovements(
    search: search,
    type: type,
    period: period,
    branchId: branchId,
    page: page,
    pageSize: pageSize,
  );
}
