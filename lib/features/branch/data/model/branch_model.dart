import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

/// A branch the customer can order from.
///
/// Prices, availability, stock and delivery all follow this selection, so it
/// is loaded from `core.branches` rather than hardcoded in the UI.
class Branch {
  const Branch({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.address,
    this.phone,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String? address;
  final String? phone;
  final bool isActive;

  String get name {
    final ar = nameAr.trim();
    final en = nameEn.trim();
    if (ar.isEmpty && en.isEmpty) return code;
    return pickText((ar: ar, en: en), isArabic: AppLocale.instance.isArabic);
  }

  factory Branch.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return Branch(
      id: Db.text(map['id']),
      code: Db.text(map['code']),
      nameAr: Db.text(map['name_ar']),
      nameEn: Db.text(map['name_en']),
      address: Db.textOrNull(map['address']),
      phone: Db.textOrNull(map['phone']),
      isActive: Db.asBool(map['is_active'], fallback: true),
    );
  }
}
