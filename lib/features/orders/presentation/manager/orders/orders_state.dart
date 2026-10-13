part of 'orders_cubit.dart';

@immutable
class OrdersState {
  const OrdersState({required this.status, required this.orders});

  final OrderStatus status;
  final List<OrderItemModel> orders;

  List<OrderItemModel> get filtered =>
      orders.where((order) => order.status == status).toList();
}
