import 'package:admin_app/features/inventory/domain/entities/admin_inventory_material_option.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';

/// بحث خيارات المواد الخام.
class SearchMaterialsUseCase {
  const SearchMaterialsUseCase(this._repository);

  final InventoryRepository _repository;

  Future<List<AdminInventoryMaterialOption>> call({
    String? search,
    String? branchId,
    int limit = 30,
  }) => _repository.searchMaterials(
    search: search,
    branchId: branchId,
    limit: limit,
  );
}
