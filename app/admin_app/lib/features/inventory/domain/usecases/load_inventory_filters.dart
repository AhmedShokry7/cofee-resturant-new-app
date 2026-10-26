import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';

/// قراءة قيم تصفية المخزون المتاحة.
class LoadInventoryFiltersUseCase {
  const LoadInventoryFiltersUseCase(this._repository);

  final InventoryRepository _repository;

  Future<AdminInventoryFilters> call() => _repository.loadFilters();
}
