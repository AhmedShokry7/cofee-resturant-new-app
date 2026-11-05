import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/order_cancellation/order_cancellation_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/track_order_view.dart';

/// One order's progress, with the cancel the customer is still allowed to do.
class TrackOrderPage extends StatelessWidget {
  const TrackOrderPage({super.key, required this.order});

  static const routeName = "trackOrderRoute";

  final OrderItemModel order;

  @override
  Widget build(BuildContext context) {
    // The invoice may be the only identifier a row carries when the order id was
    // never written back to it.
    final orderId = order.orderId.isNotEmpty ? order.orderId : order.id;
    return BlocProvider(
      create: (context) => OrderCancellationCubit(
        repository: context.read<OrdersRepository>(),
        orderId: orderId,
      ),
      child: TrackOrderView(order: order),
    );
  }
}
