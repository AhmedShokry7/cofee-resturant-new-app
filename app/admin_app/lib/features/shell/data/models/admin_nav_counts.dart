/// The unread work counters shown next to the orders and kitchen destinations.
///
/// Each counter is the work of its own section that no one has opened yet: an
/// order waiting for a confirmation is not the same question as a ticket the
/// kitchen has not been shown.
class AdminNavCounts {
  const AdminNavCounts({this.unreadOrders = 0, this.unreadKitchen = 0});

  static const AdminNavCounts empty = AdminNavCounts();

  /// Orders that still need a confirmation and no one has opened.
  final int unreadOrders;

  /// Kitchen tickets still on the board that no board has shown yet.
  final int unreadKitchen;

  bool get isEmpty => unreadOrders == 0 && unreadKitchen == 0;

  factory AdminNavCounts.fromJson(Map<String, dynamic> json) {
    return AdminNavCounts(
      unreadOrders: _toInt(json['unread_orders']),
      unreadKitchen: _toInt(json['unread_kitchen']),
    );
  }

  static int _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  @override
  bool operator ==(Object other) =>
      other is AdminNavCounts &&
      other.unreadOrders == unreadOrders &&
      other.unreadKitchen == unreadKitchen;

  @override
  int get hashCode => Object.hash(unreadOrders, unreadKitchen);
}
