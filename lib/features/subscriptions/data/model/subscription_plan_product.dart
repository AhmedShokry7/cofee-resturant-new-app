import 'package:new_coffee/core/data/db_values.dart';

class SubscriptionPlanProduct {
  const SubscriptionPlanProduct({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.imageUrl,
    this.price = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String? imageUrl;
  final double price;

  String get name => nameAr.isNotEmpty ? nameAr : nameEn;

  factory SubscriptionPlanProduct.fromDatabase(Map<String, dynamic> row) {
    final map = Db.asMap(row);
    return SubscriptionPlanProduct(
      id: Db.text(map['product_id']),
      nameAr: Db.text(map['name_ar']),
      nameEn: Db.text(map['name_en']),
      imageUrl: Db.textOrNull(map['image_url']),
      price: Db.asDouble(map['base_price']),
    );
  }
}
