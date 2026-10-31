/// The unread work counters shown next to the sidebar destinations.
///
/// Each counter is the work of its own section that no one has opened yet: an
/// order waiting for a confirmation is not the same question as a ticket the
/// kitchen has not been shown, and a notification is opened by the customer it
/// was sent to - `is_read` belongs to that customer, so this counter counts the
/// notifications no customer has opened, which is what the notifications page
/// lists when it filters to unread.
class AdminNavCounts {
  const AdminNavCounts({
    this.unreadOrders = 0,
    this.unreadKitchen = 0,
    this.unreadNotifications = 0,
  });

  static const AdminNavCounts empty = AdminNavCounts();

  /// Orders that still need a confirmation and no one has opened.
  final int unreadOrders;

  /// Kitchen tickets still on the board that no board has shown yet.
  final int unreadKitchen;

  /// Customer notifications nobody has opened yet.
  final int unreadNotifications;

  bool get isEmpty =>
      unreadOrders == 0 && unreadKitchen == 0 && unreadNotifications == 0;

  factory AdminNavCounts.fromJson(Map<String, dynamic> json) {
    return AdminNavCounts(
      unreadOrders: _toInt(json['unread_orders']),
      unreadKitchen: _toInt(json['unread_kitchen']),
      unreadNotifications: _toInt(json['unread_notifications']),
    );
  }

  /// The same counts with the notification counter replaced.
  ///
  /// The notifications count comes from a second read because
  /// `admin_nav_counts` knows only orders and kitchen; adding it there would
  /// mean a migration, and the sidebar must not wait for one.
  AdminNavCounts copyWithUnreadNotifications(int value) => AdminNavCounts(
    unreadOrders: unreadOrders,
    unreadKitchen: unreadKitchen,
    unreadNotifications: value,
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
      other.unreadNotifications == unreadNotifications;

  @override
  int get hashCode =>
      Object.hash(unreadOrders, unreadKitchen, unreadNotifications);
}
