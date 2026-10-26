import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';

/// قراءة صفحة المواد الخام.
class LoadInventoryPageUseCase {
  const LoadInventoryPageUseCase(this._repository);

  final InventoryRepository _repository;

  Future<AdminInventoryPage> call({
    String? search,
    String? category,
    String? status,
    String? branchId,
    int page = 0,
    int pageSize = 10,
  }) => _repository.loadPage(
    search: search,
    category: category,
    status: status,
    branchId: branchId,
    page: page,
    pageSize: pageSize,
  );
}
