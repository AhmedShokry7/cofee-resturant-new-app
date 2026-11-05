import 'package:flutter/material.dart';

import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_details_view.dart';

/// Full order data: tapping an order opens its receipt, and tracking or the
/// review branch out from here.
class OrderDetailsPage extends StatelessWidget {
  const OrderDetailsPage({super.key, required this.order, this.lines});

  static const routeName = "orderDetailsRoute";

  final OrderItemModel order;
  final List<OrderItemModel>? lines;

  @override
  Widget build(BuildContext context) {
    // The lines arrive with the route: a pushed page is built by the root
    // navigator, so no provider from the list screen is above it.
    return OrderDetailsView(order: order, lines: lines);
  }
}
