import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

class SubscriptionPlanProduct {
  const SubscriptionPlanProduct({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.imageUrl,
    this.price = 0,
    this.canPreorder = true,
    this.unavailableReason = '',
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final String? imageUrl;
  final double price;
  final bool canPreorder;
  final String unavailableReason;

  String get name =>
      pickText((ar: nameAr, en: nameEn), isArabic: AppLocale.instance.isArabic);
  String get description => pickText((
    ar: descriptionAr,
    en: descriptionEn,
  ), isArabic: AppLocale.instance.isArabic);

  factory SubscriptionPlanProduct.fromDatabase(Map<String, dynamic> row) {
    final map = Db.asMap(row);
    return SubscriptionPlanProduct(
      id: Db.text(map['product_id']),
      nameAr: Db.text(map['name_ar']),
      nameEn: Db.text(map['name_en']),
      descriptionAr: Db.text(map['description_ar']),
      descriptionEn: Db.text(map['description_en']),
      imageUrl: Db.textOrNull(map['image_url']),
      price: Db.asDouble(
        map['branch_price'],
        fallback: Db.asDouble(map['base_price']),
      ),
      canPreorder: Db.asBool(map['can_preorder'], fallback: true),
      unavailableReason: Db.text(map['unavailable_reason']),
    );
  }
}
