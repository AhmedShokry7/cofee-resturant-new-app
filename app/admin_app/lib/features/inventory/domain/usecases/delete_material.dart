import 'package:admin_app/features/inventory/domain/entities/inventory_mutation_outcome.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';

/// حذف مادة خام.
class DeleteMaterialUseCase {
  const DeleteMaterialUseCase(this._repository);

  final InventoryRepository _repository;

  Future<InventoryMutationOutcome> call(String materialId) =>
      _repository.deleteMaterial(materialId);
}
