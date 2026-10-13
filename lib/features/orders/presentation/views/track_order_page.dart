import 'package:flutter/material.dart';

import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_action_bottom_bar.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/track_order_page_body.dart';

class TrackOrderPage extends StatelessWidget {
  const TrackOrderPage({super.key, required this.order});

  static const routeName = "trackOrderRoute";

  final OrderItemModel order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Track Order")),
      body: TrackOrderPageBody(order: order),
      bottomNavigationBar: OrderActionBottomBar(
        onCancel: () => Navigator.of(context).pop(),
        onSubmit: () {},
      ),
    );
  }
}
