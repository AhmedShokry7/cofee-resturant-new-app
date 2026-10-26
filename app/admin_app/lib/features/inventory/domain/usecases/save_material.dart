import 'package:admin_app/features/inventory/domain/entities/admin_inventory_draft.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_material_save_outcome.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';

/// حفظ مادة خام.
class SaveMaterialUseCase {
  const SaveMaterialUseCase(this._repository);

  final InventoryRepository _repository;

  Future<InventoryMaterialSaveOutcome> call(AdminInventoryDraft draft) =>
      _repository.saveMaterial(draft);
}
