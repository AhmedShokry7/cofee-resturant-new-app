import 'package:admin_app/core/locale/app_locale.dart';

/// One raw material as the inventory directory returns it: the material master
/// plus the quantity and value aggregated over the branches in scope.
class AdminInventoryItem {
  const AdminInventoryItem({
    required this.id,
    this.sku,
    required this.nameAr,
    this.nameEn,
    this.category = '',
    this.unit = 'piece',
    this.unitCost = 0,
    this.reorderLevel = 0,
    this.quantityOnHand = 0,
    this.stockValue = 0,
    this.status = 'out',
    this.notes,
    this.lastMovementAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? sku;
  final String nameAr;
  final String? nameEn;
  final String category;

  /// One of kg, g, l, ml, piece, pack, box, bag, bottle, can.
  final String unit;
  final double unitCost;
  final double reorderLevel;
  final double quantityOnHand;
  final double stockValue;

  /// One of ok, low, out.
  final String status;
  final String? notes;
  final DateTime? lastMovementAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOut => status == 'out';
  bool get isLow => status == 'low';
  bool get isOk => !isOut && !isLow;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary?.trim();
    if (name != null && name.isNotEmpty) return name;
    return fallback?.trim() ?? '';
  }

  factory AdminInventoryItem.fromJson(Map<String, dynamic> json) {
    return AdminInventoryItem(
      id: '${json['id'] ?? ''}',
      sku: _toNullableText(json['sku']),
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: _toNullableText(json['name_en']),
      category: '${json['category'] ?? ''}',
      unit: '${json['unit'] ?? 'piece'}',
      unitCost: _toDouble(json['unit_cost']),
      reorderLevel: _toDouble(json['reorder_level']),
      quantityOnHand: _toDouble(json['quantity_on_hand']),
      stockValue: _toDouble(json['stock_value']),
      status: '${json['status'] ?? 'out'}',
      notes: _toNullableText(json['notes']),
      lastMovementAt: _toDate(json['last_movement_at']),
      createdAt: _toDate(json['created_at']),
      updatedAt: _toDate(json['updated_at']),
    );
  }

  static String? _toNullableText(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _toDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

class AdminInventoryPage {
  const AdminInventoryPage({
    this.rows = const <AdminInventoryItem>[],
    this.total = 0,
  });

  final List<AdminInventoryItem> rows;

  /// The number of materials the server matched, across every page.
  final int total;

  factory AdminInventoryPage.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'];
    return AdminInventoryPage(
      rows: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => AdminInventoryItem.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const <AdminInventoryItem>[],
      total: _toInt(json['total']),
    );
  }

  static int _toInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
}
