import 'package:admin_app/core/locale/app_locale.dart';

/// A raw material offered by the movement dialog, with the on-hand quantity
/// for the branch chosen in the dialog.
class AdminInventoryMaterialOption {
  const AdminInventoryMaterialOption({
    required this.id,
    this.sku,
    required this.nameAr,
    this.nameEn,
    this.unit = 'piece',
    this.unitCost = 0,
    this.reorderLevel = 0,
    this.quantityOnHand = 0,
  });

  final String id;
  final String? sku;
  final String nameAr;
  final String? nameEn;
  final String unit;
  final double unitCost;
  final double reorderLevel;
  final double quantityOnHand;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary?.trim();
    if (name != null && name.isNotEmpty) return name;
    return fallback?.trim() ?? '';
  }

  factory AdminInventoryMaterialOption.fromJson(Map<String, dynamic> json) {
    return AdminInventoryMaterialOption(
      id: '${json['id'] ?? ''}',
      sku: _toNullableText(json['sku']),
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: _toNullableText(json['name_en']),
      unit: '${json['unit'] ?? 'piece'}',
      unitCost: _toDouble(json['unit_cost']),
      reorderLevel: _toDouble(json['reorder_level']),
      quantityOnHand: _toDouble(json['quantity_on_hand']),
    );
  }

  static String? _toNullableText(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? null : text;
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }
}
