/// The live work counters shown next to the orders and kitchen destinations.
class AdminNavCounts {
  const AdminNavCounts({this.newOrders = 0, this.kitchenQueue = 0});

  static const AdminNavCounts empty = AdminNavCounts();

  /// Orders waiting for a confirmation.
  final int newOrders;

  /// Kitchen tickets that have not been started yet.
  final int kitchenQueue;

  bool get isEmpty => newOrders == 0 && kitchenQueue == 0;

  factory AdminNavCounts.fromJson(Map<String, dynamic> json) {
    return AdminNavCounts(
      newOrders: _toInt(json['new_orders']),
      kitchenQueue: _toInt(json['kitchen_queue']),
    );
  }

  static int _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  @override
  bool operator ==(Object other) =>
      other is AdminNavCounts &&
      other.newOrders == newOrders &&
      other.kitchenQueue == kitchenQueue;

  @override
  int get hashCode => Object.hash(newOrders, kitchenQueue);
}
