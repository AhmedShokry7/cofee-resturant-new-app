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
    this.productDiscountTotal = 0,
  });

  final String orderId;
  final String orderNumber;
  final double subtotal;

  /// The coupon.
  final double discountTotal;

  /// The product discount. It is already inside [subtotal].
  final double productDiscountTotal;

  final double deliveryFee;
  final double taxTotal;
  final double grandTotal;
  final int pointsEarned;
  final DateTime placedAt;
}

/// Authoritative checkout prices returned by the same database rules used to
/// persist the invoice.
class CheckoutQuote {
  const CheckoutQuote({
    required this.subtotal,
    required this.discountTotal,
    required this.deliveryFee,
    required this.taxTotal,
    required this.grandTotal,
    required this.currencyCode,
    this.productDiscountTotal = 0,
  });

  final double subtotal;

  /// The coupon.
  final double discountTotal;

  /// The product discount. It is already inside [subtotal], so it is a
  /// separate figure: the invoice shows the price before the discount, then
  /// the discount, and the subtotal is what is left.
  final double productDiscountTotal;

  final double deliveryFee;
  final double taxTotal;
  final double grandTotal;
  final String currencyCode;
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

  /// Replaces the caller's active server cart in one server transaction.
  ///
  /// If validation or repricing of any line fails, the previous cart is kept.
  ///
  /// Needed before any server-side check that reads `orders.cart_items`, since
  /// those checks (`validate_coupon`) see only what was last mirrored, and the
  /// device cart is the checkout source of truth.
  Future<void> syncCart({
    required String branchId,
    required List<PlaceOrderLine> lines,
  });

  /// Replaces the server cart and places its order in one server transaction.
  ///
  /// [idempotencyKey] stays fixed across retries of this logical purchase and
  /// changes for a new purchase. [lines] carry no price: the server validates
  /// options and re-prices from the catalogue before creating the order.
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  });

  /// Cancels the whole order header. There is no supported customer transition
  /// other than cancellation.
  Future<void> cancelOrder(String orderId, {String? reason});

  /// Status transitions recorded by the server, oldest first.
  Future<List<OrderStatusEvent>> orderHistory(String orderId);
}

/// Optional read of one order's frozen lines by id.
///
/// A notification names an order and carries no rows of its own, and that id
/// can point at an order older than any window the list reads, so a repository
/// that can ask the server for one order answers it in one owner-scoped query
/// instead of scanning recent lines and hoping the order is in the window.
///
/// Separate from [OrdersRepository] for the same reason as
/// [CheckoutQuoteRepository]: local fakes and the read-only fallback keep their
/// smaller contract and do not have to implement a lookup they cannot serve.
abstract interface class OrderLinesRepository {
  /// The lines of [orderId], oldest first, or an empty list when the id is not
  /// an order of the signed-in customer. The read stays owner-scoped, so
  /// another customer's id is an empty list rather than their receipt.
  Future<List<OrderItemModel>> orderLines(String orderId);
}

/// Optional server pricing capability, separate so local fakes and
/// read-only order repositories keep their smaller contract.
abstract interface class CheckoutQuoteRepository {
  Future<CheckoutQuote> quoteCheckout({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String fulfillmentType,
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
  });

  Future<PlacedOrder> placeOrderWithQuote({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    required double expectedTotal,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  });
}

/// Optional write of a product review.
///
/// A review belongs to a product, not to the order that produced it: the server
/// stores one row per customer and product, so a second purchase of the same
/// drink updates the first review instead of piling up a second one.
///
/// Separate from [OrdersRepository] for the same reason as
/// [OrderLinesRepository]: the read-only fallback has no backend to write to and
/// must not be forced to promise one.
abstract interface class ReviewRepository {
  /// Stores [rating] (1-5) and the optional [body] for [productId].
  ///
  /// Throws [OrderSignInRequiredException] when nobody is signed in: the row is
  /// owned by `auth.uid()`, and the server refuses one that names anyone else.
  Future<void> submitReview({
    required String productId,
    String? orderId,
    required int rating,
    String? body,
  });
}
