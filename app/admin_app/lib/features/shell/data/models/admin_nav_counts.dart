/// The unread work counters shown next to the sidebar destinations.
///
/// Counts stay separate so each destination shows only work that needs action.
class AdminNavCounts {
  const AdminNavCounts({
    this.unreadOrders = 0,
    this.unreadKitchen = 0,
    this.unreadNotifications = 0,
    this.eventRequests = 0,
  });

  static const AdminNavCounts empty = AdminNavCounts();

  /// Orders that still need a confirmation and no one has opened.
  final int unreadOrders;

  /// Kitchen tickets still on the board that no board has shown yet.
  final int unreadKitchen;

  /// Customer notifications nobody has opened yet.
  final int unreadNotifications;

  /// Event requests waiting for a quote or a revised quote from the branch.
  final int eventRequests;

  bool get isEmpty =>
      unreadOrders == 0 &&
      unreadKitchen == 0 &&
      unreadNotifications == 0 &&
      eventRequests == 0;

  factory AdminNavCounts.fromJson(Map<String, dynamic> json) {
    return AdminNavCounts(
      unreadOrders: _toInt(json['unread_orders']),
      unreadKitchen: _toInt(json['unread_kitchen']),
      unreadNotifications: _toInt(json['unread_notifications']),
      eventRequests: _toInt(json['event_requests']),
    );
  }

  /// The same counts with the notification counter replaced.
  AdminNavCounts copyWithUnreadNotifications(int value) => AdminNavCounts(
    unreadOrders: unreadOrders,
    unreadKitchen: unreadKitchen,
    unreadNotifications: value,
    eventRequests: eventRequests,
  );

  static int _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  @override
  bool operator ==(Object other) =>
      other is AdminNavCounts &&
      other.unreadOrders == unreadOrders &&
      other.unreadKitchen == unreadKitchen &&
      other.unreadNotifications == unreadNotifications &&
      other.eventRequests == eventRequests;

  @override
  int get hashCode => Object.hash(
    unreadOrders,
    unreadKitchen,
    unreadNotifications,
    eventRequests,
  );
}
