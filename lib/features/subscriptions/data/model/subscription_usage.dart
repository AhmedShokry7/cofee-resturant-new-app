import 'package:new_coffee/core/data/db_values.dart';

class SubscriptionUsage {
  const SubscriptionUsage({
    required this.id,
    required this.subscriptionId,
    required this.branchId,
    this.productId,
    this.productName,
    this.quantity = 1,
    this.method = 'qr',
    this.createdAt,
  });

  final String id;
  final String subscriptionId;
  final String branchId;
  final String? productId;
  final String? productName;
  final int quantity;
  final String method;
  final DateTime? createdAt;

  factory SubscriptionUsage.fromDatabase(Map<String, dynamic> row) {
    final map = Db.asMap(row);
    final created = Db.textOrNull(map['created_at']);
    return SubscriptionUsage(
      id: Db.text(map['id']),
      subscriptionId: Db.text(map['subscription_id']),
      branchId: Db.text(map['branch_id']),
      productId: Db.textOrNull(map['product_id']),
      productName: Db.textOrNull(map['product_name']),
      quantity: Db.asInt(map['quantity'], fallback: 1),
      method: Db.text(map['method'], 'qr'),
      createdAt: created == null ? null : DateTime.tryParse(created)?.toLocal(),
    );
  }
}
