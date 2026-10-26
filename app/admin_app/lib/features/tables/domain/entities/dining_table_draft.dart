import 'package:admin_app/core/models/dining_table.dart';

/// The editable fields of a table/room.
class DiningTableDraft {
  const DiningTableDraft({
    this.id,
    required this.branchId,
    required this.name,
    this.area = 'hall',
    this.capacity = 2,
    this.note = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String? id;
  final String branchId;
  final String name;
  final String area;
  final int capacity;
  final String note;
  final int sortOrder;
  final bool isActive;

  Map<String, Object?> toJson() {
    return {
      if (id != null) 'id': id,
      'branch_id': branchId,
      'name': name.trim(),
      'area': area,
      'capacity': capacity,
      'note': note.trim(),
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  factory DiningTableDraft.fromTable(DiningTable table) {
    return DiningTableDraft(
      id: table.id,
      branchId: table.branchId,
      name: table.name,
      area: table.area.value,
      capacity: table.capacity,
      note: table.note,
      sortOrder: table.sortOrder,
      isActive: table.isActive,
    );
  }
}
