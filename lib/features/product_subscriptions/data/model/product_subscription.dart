import 'package:new_coffee/core/data/db_values.dart';

class ProductSubscriptionItem {
  const ProductSubscriptionItem({required this.productId, required this.quantity, this.productNameAr, this.productNameEn});
  final String productId;
  final int quantity;
  final String? productNameAr;
  final String? productNameEn;
  factory ProductSubscriptionItem.fromJson(Map<String, dynamic> j) => ProductSubscriptionItem(
    productId: Db.text(j['product_id']),
    quantity: Db.asInt(j['quantity'], fallback: 1),
    productNameAr: Db.textOrNull(j['product_name_ar']),
    productNameEn: Db.textOrNull(j['product_name_en']),
  );
}

class ProductSubscription {
  const ProductSubscription({
    required this.id, required this.status, required this.frequency, required this.branchId,
    this.name, this.nextRunAt, this.lastRunAt, this.fulfillmentType = 'pickup', this.items = const [],
  });
  final String id;
  final String status;
  final String frequency;
  final String branchId;
  final String? name;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final String fulfillmentType;
  final List<ProductSubscriptionItem> items;

  factory ProductSubscription.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'];
    return ProductSubscription(
      id: Db.text(j['id']),
      status: Db.text(j['status'], 'active'),
      frequency: Db.text(j['frequency'], 'weekly'),
      branchId: Db.text(j['branch_id']),
      name: Db.textOrNull(j['name']),
      nextRunAt: Db.asDateTimeOrNull(j['next_run_at']),
      lastRunAt: Db.asDateTimeOrNull(j['last_run_at']),
      fulfillmentType: Db.text(j['fulfillment_type'], 'pickup'),
      items: rawItems is List ? rawItems.whereType<Map>().map((e)=>ProductSubscriptionItem.fromJson(Map<String,dynamic>.from(e))).toList() : const [],
    );
  }
}
