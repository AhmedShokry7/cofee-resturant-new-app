/// The editable fields of a raw material, sent to
/// `admin_save_inventory_material`.
class AdminInventoryDraft {
  const AdminInventoryDraft({
    this.id,
    this.sku,
    required this.nameAr,
    this.nameEn,
    this.category = '',
    this.unit = 'piece',
    this.unitCost = 0,
    this.reorderLevel = 0,
    this.notes,
  });

  final String? id;
  final String? sku;
  final String nameAr;
  final String? nameEn;
  final String category;
  final String unit;
  final double unitCost;
  final double reorderLevel;
  final String? notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'sku': sku,
    'name_ar': nameAr,
    'name_en': nameEn,
    'category': category,
    'unit': unit,
    'unit_cost': unitCost,
    'reorder_level': reorderLevel,
    'notes': notes,
  };
}
