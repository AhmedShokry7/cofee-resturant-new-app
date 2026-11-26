import 'package:new_coffee/core/data/db_values.dart';

class ProductSubscriptionItem {
  const ProductSubscriptionItem({
    required this.productId,
    required this.quantity,
    this.productNameAr,
    this.productNameEn,
    this.note,
    this.optionValueIds = const [],
  });
  final String productId;
  final int quantity;
  final String? productNameAr;
  final String? productNameEn;
  final String? note;
  final List<String> optionValueIds;
  factory ProductSubscriptionItem.fromJson(Map<String, dynamic> j) =>
      ProductSubscriptionItem(
        productId: Db.text(j['product_id']),
        quantity: Db.asInt(j['quantity'], fallback: 1),
        productNameAr: Db.textOrNull(j['product_name_ar']),
        productNameEn: Db.textOrNull(j['product_name_en']),
        note: Db.textOrNull(j['note']),
        optionValueIds: _optionIds(j['selected_options']),
      );

  static List<String> _optionIds(Object? raw) {
    if (raw is! Map) return const [];
    final ids = <String>{};
    for (final value in raw.values) {
      if (value is String && value.trim().isNotEmpty) ids.add(value.trim());
      if (value is List) {
        ids.addAll(value.whereType<String>().where((id) => id.trim().isNotEmpty));
      }
    }
    return ids.toList()..sort();
  }
}

class ProductSubscriptionRun {
  const ProductSubscriptionRun({
    required this.id,
    required this.scheduledFor,
  });

  final String id;
  final DateTime scheduledFor;

  factory ProductSubscriptionRun.fromJson(Map<String, dynamic> json) =>
      ProductSubscriptionRun(
        id: Db.text(json['id']),
        scheduledFor: Db.asDateTime(json['scheduled_for']),
      );
}

class ProductSubscription {
  const ProductSubscription({
    required this.id,
    required this.status,
    required this.frequency,
    this.intervalValue = 1,
    required this.branchId,
    this.name,
    this.nextRunAt,
    this.lastRunAt,
    this.fulfillmentType = 'pickup',
    this.deliveryAddressId,
    this.items = const [],
    this.pendingRuns = const [],
  });
  final String id;
  final String status;
  final String frequency;
  final int intervalValue;
  final String branchId;
  final String? name;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final String fulfillmentType;
  final String? deliveryAddressId;
  final List<ProductSubscriptionItem> items;
  final List<ProductSubscriptionRun> pendingRuns;

  factory ProductSubscription.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'];
    final rawRuns = j['pending_runs'];
    return ProductSubscription(
      id: Db.text(j['id']),
      status: Db.text(j['status'], 'active'),
      frequency: Db.text(j['recurrence_type'] ?? j['frequency'], 'weekly'),
      intervalValue: Db.asInt(j['interval_value'], fallback: 1),
      branchId: Db.text(j['branch_id']),
      name: Db.textOrNull(j['name']),
      nextRunAt: Db.asDateTimeOrNull(j['next_run_at']),
      lastRunAt: Db.asDateTimeOrNull(j['last_run_at']),
      fulfillmentType: Db.text(j['fulfillment_type'], 'pickup'),
      deliveryAddressId: Db.textOrNull(j['delivery_address_id']),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (e) => ProductSubscriptionItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
      pendingRuns: rawRuns is List
          ? rawRuns
                .whereType<Map>()
                .map(
                  (e) => ProductSubscriptionRun.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
    );
  }
}
