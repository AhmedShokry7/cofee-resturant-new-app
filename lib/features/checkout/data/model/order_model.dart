import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';

/// The just-placed order shown on the success screen and e-receipt.
///
/// Totals come from the server's `place_order` answer, and the delivery fields
/// mirror the selection the customer made, so the receipt matches the invoice
/// the server persisted.
class OrderModel {
  const OrderModel({
    required this.id,
    this.orderId = '',
    required this.date,
    required this.items,
    required this.total,
    this.fulfillmentType = 'pickup',
    this.deliveryFee = 0,
    this.deliveryZoneName,
    this.deliveryAddress,
    this.discountLines = const [],
    this.productDiscount = 0,
  });

  /// The number the customer reads, e.g. `ORD-2026-000123`.
  final String id;

  /// The server's own id of the order (a uuid).
  ///
  /// The number is a label; the uuid is the key every server call uses
  /// (charging, cancelling, reading the history). They are not the same
  /// string, so both are kept: the receipt shows [id], the payment uses
  /// [orderId].
  final String orderId;
  final DateTime date;
  final List<CartItem> items;
  final double total;
  final String fulfillmentType;
  final double deliveryFee;
  final String? deliveryZoneName;
  final String? deliveryAddress;

  /// Per-line attribution of the coupon discount, when one was applied.
  ///
  /// Empty when no coupon was applied, or when the server could not break it
  /// down (older deployment): the total is still correct in both cases, only
  /// the explanation is missing.
  final List<CouponLineDiscount> discountLines;

  /// The product discount of the order.
  ///
  /// It is already inside the total, so it is a separate figure: the receipt
  /// shows the price before the discount, then the discount, and the total is
  /// what the customer pays.
  final double productDiscount;

  bool get isDelivery => fulfillmentType == 'delivery';

  /// True when some lines were excluded from the discount, which is the case
  /// worth explaining on the receipt.
  bool get hasPartialDiscount =>
      discountLines.isNotEmpty &&
      discountLines.any((line) => line.discount > 0) &&
      discountLines.any((line) => line.discount <= 0);
}
