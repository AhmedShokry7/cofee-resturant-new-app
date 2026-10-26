import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement_draft.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_movement_outcome.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';

/// تسجيل حركة مخزون.
class RecordMovementUseCase {
  const RecordMovementUseCase(this._repository);

  final InventoryRepository _repository;

  Future<InventoryMovementOutcome> call(AdminStockMovementDraft draft) =>
      _repository.recordMovement(draft);
}
