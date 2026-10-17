import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

/// A delivery zone the selected branch serves.
///
/// Loaded from the `delivery_zones_for_branch` bridge, so the checkout only
/// ever offers zones the branch actually delivers to. The fee and minimum are
/// the branch's own zone values, never a client-side constant.
class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.deliveryFee,
    this.minOrderAmount = 0,
    this.estimatedMinutes,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final double deliveryFee;
  final double minOrderAmount;
  final int? estimatedMinutes;

  String get name {
    final ar = nameAr.trim();
    final en = nameEn.trim();
    if (ar.isEmpty && en.isEmpty) return id;
    return pickText((ar: ar, en: en), isArabic: AppLocale.instance.isArabic);
  }

  factory DeliveryZone.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return DeliveryZone(
      id: Db.text(map['id']),
      nameAr: Db.text(map['name_ar']),
      nameEn: Db.text(map['name_en']),
      deliveryFee: Db.asDouble(map['delivery_fee']),
      minOrderAmount: Db.asDouble(map['min_order_amount']),
      estimatedMinutes: (map['estimated_minutes'] as num?)?.toInt(),
    );
  }
}
