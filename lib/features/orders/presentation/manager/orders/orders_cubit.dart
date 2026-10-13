import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/orders_list.dart';

part 'orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit()
      : super(
          OrdersState(status: OrderStatus.active, orders: getOrdersList()),
        );

  void selectStatus(OrderStatus status) {
    emit(OrdersState(status: status, orders: state.orders));
  }
}
