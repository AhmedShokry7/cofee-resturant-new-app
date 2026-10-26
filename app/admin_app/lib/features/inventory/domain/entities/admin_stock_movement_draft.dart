import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement.dart';

/// The fields of one stock movement, sent to
/// `admin_record_inventory_movement`.
class AdminStockMovementDraft {
  const AdminStockMovementDraft({
    required this.materialId,
    required this.branchId,
    required this.type,
    required this.quantity,
    this.unitCost,
    this.reference,
    this.note,
  });

  final String materialId;
  final String branchId;
  final InventoryMovementType type;
  final double quantity;
  final double? unitCost;
  final String? reference;
  final String? note;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'material_id': materialId,
    'branch_id': branchId,
    'type': type.value,
    'quantity': quantity,
    if (unitCost != null) 'unit_cost': unitCost,
    'reference': reference,
    'note': note,
  };
}
