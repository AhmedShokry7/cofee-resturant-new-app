import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_strings.dart';

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

  /// The product the cup was spent on.
  ///
  /// `subscription_usage_history` returns only `product_id`, so this is empty
  /// until the cubit joins it with the plan's product list; the history row
  /// falls back to the redemption method while it is null.
  final String? productName;
  final int quantity;

  /// `'qr'` or `'cashier'`, straight from the history table.
  final String method;

  /// How the cup was spent, in the language the customer reads the app in.
  ///
  /// The column value is never shown: 'qr' is not a sentence, and a method this
  /// app has not been told about reads as a redemption rather than as a
  /// database word the customer has to guess.
  String get methodLabel => switch (method) {
    'qr' => S.usageByQr,
    'cashier' => S.usageByCashier,
    _ => S.usageUnknownMethod,
  };

  /// What the row is titled: the drink, or how it was taken out.
  String get title => productName ?? methodLabel;

  final DateTime? createdAt;

  SubscriptionUsage copyWith({String? productName}) {
    return SubscriptionUsage(
      id: id,
      subscriptionId: subscriptionId,
      branchId: branchId,
      productId: productId,
      productName: productName ?? this.productName,
      quantity: quantity,
      method: method,
      createdAt: createdAt,
    );
  }

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
