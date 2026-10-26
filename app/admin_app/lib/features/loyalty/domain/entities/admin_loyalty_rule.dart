import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/loyalty/domain/entities/loyalty_json.dart';

class AdminLoyaltyRule {
  const AdminLoyaltyRule({
    required this.id,
    required this.code,
    this.nameAr,
    this.nameEn,
    this.pointsPerCurrencyUnit = 0,
    this.pointValue = 0,
    this.isActive = true,
    this.isCurrent = false,
    this.validFrom,
    this.validTo,
  });

  final String id;
  final String code;
  final String? nameAr;
  final String? nameEn;
  final double pointsPerCurrencyUnit;
  final double pointValue;
  final bool isActive;
  final bool isCurrent;
  final DateTime? validFrom;
  final DateTime? validTo;

  bool get isOpenEnded => validTo == null;

  String nameFor(AppLanguage language) {
    final name = language.isArabic ? nameAr?.trim() : nameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic ? nameEn?.trim() : nameAr?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return code;
  }

  factory AdminLoyaltyRule.fromJson(Map<String, dynamic> json) {
    return AdminLoyaltyRule(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      nameAr: json['name_ar'] as String?,
      nameEn: json['name_en'] as String?,
      pointsPerCurrencyUnit: loyaltyDouble(json['points_per_currency_unit']),
      pointValue: loyaltyDouble(json['point_value']),
      isActive: json['is_active'] == true,
      isCurrent: json['is_current'] == true,
      validFrom: loyaltyDate(json['valid_from']),
      validTo: loyaltyDate(json['valid_to']),
    );
  }
}
