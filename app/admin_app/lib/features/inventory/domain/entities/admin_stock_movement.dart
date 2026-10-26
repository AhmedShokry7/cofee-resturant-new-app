import 'package:admin_app/core/locale/app_locale.dart';

enum InventoryMovementType {
  receipt('receipt'),
  issue('issue'),
  waste('waste'),
  count('count');

  const InventoryMovementType(this.value);

  final String value;

  static InventoryMovementType? fromValue(String? value) {
    for (final type in InventoryMovementType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// One row of the raw-material movement ledger.
class AdminStockMovement {
  const AdminStockMovement({
    required this.id,
    this.createdAt,
    this.type = '',
    this.quantityDelta = 0,
    this.balanceAfter = 0,
    this.unitCost = 0,
    this.movementValue = 0,
    this.reference,
    this.note,
    this.materialId = '',
    this.materialSku,
    this.materialNameAr = '',
    this.materialNameEn,
    this.unit = 'piece',
    this.branchId = '',
    this.branchCode = '',
    this.branchNameAr = '',
    this.branchNameEn,
    this.actorName,
    this.actorEmail,
  });

  final int id;
  final DateTime? createdAt;

  /// receipt, issue, waste or count.
  final String type;
  final double quantityDelta;
  final double balanceAfter;
  final double unitCost;
  final double movementValue;
  final String? reference;
  final String? note;
  final String materialId;
  final String? materialSku;
  final String materialNameAr;
  final String? materialNameEn;
  final String unit;
  final String branchId;
  final String branchCode;
  final String branchNameAr;
  final String? branchNameEn;
  final String? actorName;
  final String? actorEmail;

  InventoryMovementType? get movementType =>
      InventoryMovementType.fromValue(type);

  bool get isInbound => quantityDelta > 0;

  String materialNameFor(AppLanguage language) {
    final primary = language.isArabic ? materialNameAr : materialNameEn;
    final fallback = language.isArabic ? materialNameEn : materialNameAr;
    final name = primary?.trim();
    if (name != null && name.isNotEmpty) return name;
    return fallback?.trim() ?? '';
  }

  String branchNameFor(AppLanguage language) {
    final primary = language.isArabic ? branchNameAr : branchNameEn;
    final fallback = language.isArabic ? branchNameEn : branchNameAr;
    final name = primary?.trim();
    if (name != null && name.isNotEmpty) return name;
    return fallback?.trim() ?? '';
  }

  factory AdminStockMovement.fromJson(Map<String, dynamic> json) {
    return AdminStockMovement(
      id: _toInt(json['id']),
      createdAt: _toDate(json['created_at']),
      type: '${json['movement_type'] ?? ''}',
      quantityDelta: _toDouble(json['quantity_delta']),
      balanceAfter: _toDouble(json['balance_after']),
      unitCost: _toDouble(json['unit_cost']),
      movementValue: _toDouble(json['movement_value']),
      reference: _toNullableText(json['reference']),
      note: _toNullableText(json['note']),
      materialId: '${json['material_id'] ?? ''}',
      materialSku: _toNullableText(json['material_sku']),
      materialNameAr: '${json['material_name_ar'] ?? ''}',
      materialNameEn: _toNullableText(json['material_name_en']),
      unit: '${json['unit'] ?? 'piece'}',
      branchId: '${json['branch_id'] ?? ''}',
      branchCode: '${json['branch_code'] ?? ''}',
      branchNameAr: '${json['branch_name_ar'] ?? ''}',
      branchNameEn: _toNullableText(json['branch_name_en']),
      actorName: _toNullableText(json['actor_name']),
      actorEmail: _toNullableText(json['actor_email']),
    );
  }

  static int _toInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
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

class AdminStockMovementPage {
  const AdminStockMovementPage({
    this.rows = const <AdminStockMovement>[],
    this.total = 0,
  });

  final List<AdminStockMovement> rows;

  /// The number of movements the server matched, across every page.
  final int total;

  factory AdminStockMovementPage.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'];
    return AdminStockMovementPage(
      rows: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => AdminStockMovement.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const <AdminStockMovement>[],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
