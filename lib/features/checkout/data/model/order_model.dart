import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';

class OrderModel {
  const OrderModel({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
  });

  final String id;
  final DateTime date;
  final List<CartItem> items;
  final double total;
}
