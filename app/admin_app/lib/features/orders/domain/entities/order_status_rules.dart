import 'package:admin_app/core/models/order_status_codes.dart';

/// The allowed order status transitions, exactly as the database holds them in
/// `orders.status_transitions` and returns them from
/// `admin_order_status_matrix()` (migration 195).
///
/// The schema owns this matrix: `orders.update_order_status` (079) and
/// `orders.cancel_order` (107) both refuse an edge that is not in it. A menu
/// built from any other list therefore offers actions the server rejects, which
/// is what the admin used to see as a generic failure toast.
class OrderStatusRules {
  const OrderStatusRules({required this.canCancel, required this.edges});

  /// Reads the RPC payload `{"can_cancel": …, "matrix": {from: [to, …]}}`.
  factory OrderStatusRules.fromJson(Map<Object?, Object?> json) {
    final raw = json['matrix'];
    final edges = <String, List<String>>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final from = entry.key;
        final to = entry.value;
        if (from is! String || to is! List) continue;
        edges[from] = to.whereType<String>().toList(growable: false);
      }
    }
    return OrderStatusRules(
      canCancel: json['can_cancel'] == true,
      edges: edges,
    );
  }

  /// Whether the signed-in staff member holds `orders.cancel`, the permission
  /// the cancellation path demands.
  final bool canCancel;

  /// Allowed targets per current status. A status with no outgoing edge is
  /// absent, which is how a closed order arrives.
  final Map<String, List<String>> edges;

  /// The statuses this staff member may move [status] to right now.
  ///
  /// An empty list is an answer, not a missing read: it means the order is
  /// closed, or that only a cancel edge led out of it and this role may not
  /// cancel.
  List<String> allowedFor(String status) {
    final targets = edges[status] ?? const <String>[];
    if (canCancel) return targets;
    return targets
        .where((code) => code != OrderStatusCodes.cancelled)
        .toList(growable: false);
  }
}
