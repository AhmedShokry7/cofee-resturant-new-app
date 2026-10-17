import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';

/// The just-placed order shown on the success screen and e-receipt.
///
/// Totals come from the server's `place_order` answer, and the delivery fields
/// mirror the selection the customer made, so the receipt matches the invoice
/// the server persisted.
class OrderModel {
  const OrderModel({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    this.fulfillmentType = 'pickup',
    this.deliveryFee = 0,
    this.deliveryZoneName,
    this.deliveryAddress,
  });

  final String id;
  final DateTime date;
  final List<CartItem> items;
  final double total;

  /// `pickup` or `delivery`, frozen from the server answer.
  final String fulfillmentType;

  /// Delivery fee charged by the server (zero for pickup).
  final double deliveryFee;

  /// The chosen zone's display name, when delivered.
  final String? deliveryZoneName;

  /// The delivery address as one line (`label - details`), when delivered.
  final String? deliveryAddress;

  bool get isDelivery => fulfillmentType == 'delivery';
}
