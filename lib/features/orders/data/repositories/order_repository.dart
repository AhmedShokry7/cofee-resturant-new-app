import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';

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

  /// Cancels the whole order header. There is no supported customer transition
  /// other than cancellation.
  Future<void> cancelOrder(String orderId, {String? reason});
}
