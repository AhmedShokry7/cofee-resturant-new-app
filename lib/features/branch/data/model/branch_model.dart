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
    String? address,
    this.addressAr,
    this.addressEn,
    this.latitude,
    this.longitude,
    this.phone,
    this.isActive = true,
  }) : _legacyAddress = address;

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String? addressAr;
  final String? addressEn;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final bool isActive;
  final String? _legacyAddress;

  String? get address {
    final ar = addressAr ?? '';
    final en = addressEn ?? '';
    if (ar.trim().isEmpty && en.trim().isEmpty) return _legacyAddress;
    final localized = pickText((
      ar: ar,
      en: en,
    ), isArabic: AppLocale.instance.isArabic);
    return localized.isEmpty ? _legacyAddress : localized;
  }

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
      addressAr: Db.textOrNull(map['address_ar']),
      addressEn: Db.textOrNull(map['address_en']),
      latitude: Db.asDoubleOrNull(map['latitude']),
      longitude: Db.asDoubleOrNull(map['longitude']),
      phone: Db.textOrNull(map['phone']),
      isActive: Db.asBool(map['is_active'], fallback: true),
    );
  }
}
