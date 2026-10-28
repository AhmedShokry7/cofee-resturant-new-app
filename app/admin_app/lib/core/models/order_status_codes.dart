/// The status codes shared between the dashboard and the `orders.status`
/// column, so one code is written once instead of re-typed in every filter,
/// tab, metric and edit rule.
class OrderStatusCodes {
  const OrderStatusCodes._();

  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String preparing = 'preparing';
  static const String ready = 'ready';
  static const String outForDelivery = 'out_for_delivery';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  /// Every code the dashboard may read, in the flow's own order.
  static const List<String> all = <String>[
    pending,
    confirmed,
    preparing,
    ready,
    outForDelivery,
    completed,
    cancelled,
  ];

  /// The work still inside the branch: not on the road and not closed.
  static const Set<String> processing = <String>{
    pending,
    confirmed,
    preparing,
    ready,
  };

  /// Orders the customer has left behind, so their items must not move.
  static const Set<String> closed = <String>{completed, cancelled};
}
