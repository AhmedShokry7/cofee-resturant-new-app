import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';

List<OrderItemModel> getOrdersList() {
  final menu = getMenuList();
  return [
    OrderItemModel(
      id: "1",
      product: menu[0],
      status: OrderStatus.active,
      quantity: 2,
    ),
    OrderItemModel(id: "2", product: menu[1], status: OrderStatus.active),
    OrderItemModel(
      id: "3",
      product: menu[2],
      status: OrderStatus.completed,
      quantity: 3,
    ),
    OrderItemModel(id: "4", product: menu[3], status: OrderStatus.completed),
    OrderItemModel(id: "5", product: menu[4], status: OrderStatus.cancelled),
  ];
}
