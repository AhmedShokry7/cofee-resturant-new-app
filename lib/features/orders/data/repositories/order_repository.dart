import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';

/// Thrown when order history is requested without a signed-in customer.
///
/// Order rows are owned by `auth.uid()` and the bridge grants them to
/// `authenticated` only. Anonymous callers legitimately have no history, so a
/// distinct exception lets the UI offer sign-in instead of reporting an empty
/// list or a database error.
class OrderSignInRequiredException implements Exception {
  const OrderSignInRequiredException();

  @override
  String toString() => 'Sign in to view order history.';
}

/// One cart line as the server needs it: identity and quantity only.
///
/// The client never sends a price. `place_order` re-prices every line from the
/// catalogue, so a tampered or stale device price cannot reach an invoice.
class PlaceOrderLine {
  const PlaceOrderLine({
    required this.productId,
    required this.quantity,
    this.note = '',
    this.optionValueIds = const [],
    this.bundleId,
  });

  final String productId;
  final int quantity;
  final String note;
  final List<String> optionValueIds;

  /// Set when this line is a bundle component, so the server keeps charging
  /// its share of the bundle price instead of the shelf price.
  final String? bundleId;
}

/// The server's answer to a successful `place_order`.
///
/// Totals are the server's own arithmetic, not the client's: the receipt must
/// show what was actually persisted.
class PlacedOrder {
  const PlacedOrder({
    required this.orderId,
    required this.orderNumber,
    required this.subtotal,
    required this.discountTotal,
    required this.deliveryFee,
    required this.taxTotal,
    required this.grandTotal,
    required this.pointsEarned,
    required this.placedAt,
  });

  final String orderId;
  final String orderNumber;
  final double subtotal;
  final double discountTotal;
  final double deliveryFee;
  final double taxTotal;
  final double grandTotal;
  final int pointsEarned;
  final DateTime placedAt;
}

/// Customer-facing order history.
///
/// The implementation returns frozen invoice lines. Every name and price comes
/// from `orders.order_items`, never from the live catalogue, so repricing a
/// product does not rewrite history.
abstract class OrdersRepository {
  /// Most recent lines first. When [status] is supplied, only lines whose
  /// order header is in that customer-facing bucket are returned.
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  });

  /// Places the customer's cart on the server, atomically and idempotently.
  ///
  /// The device cart is rebuilt server-side from [lines] first (the caller's
  /// own active cart is emptied, then each line is re-added), so the server
  /// cart always matches what the customer actually sees. [lines] carry no
  /// price: `place_order` re-prices from the catalogue and re-validates every
  /// option selection.
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? couponCode,
    String? note,
  });

  /// Cancels the whole order header. There is no supported customer transition
  /// other than cancellation.
  Future<void> cancelOrder(String orderId, {String? reason});

  /// Status transitions recorded by the server, oldest first.
  Future<List<OrderStatusEvent>> orderHistory(String orderId);
}
