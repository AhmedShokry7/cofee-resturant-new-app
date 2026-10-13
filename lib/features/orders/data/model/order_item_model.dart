import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';

class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.product,
    required this.status,
    this.quantity = 1,
  });

  final String id;
  final ProductModel product;
  final OrderStatus status;
  final int quantity;
}
