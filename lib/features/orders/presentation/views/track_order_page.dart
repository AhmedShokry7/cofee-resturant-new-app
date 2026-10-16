import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_action_bottom_bar.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/track_order_page_body.dart';

class TrackOrderPage extends StatelessWidget {
  const TrackOrderPage({super.key, required this.order});

  static const routeName = "trackOrderRoute";

  final OrderItemModel order;

  void _cancelOrder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<OrdersCubit>().cancelOrder(order);
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(S.cancelFailed('$error'))),
        );
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(S.orderCancelled)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.trackOrder)),
      body: TrackOrderPageBody(order: order),
      bottomNavigationBar: OrderActionBottomBar(
        cancelText: S.cancelOrder,
        submitText: S.back,
        onCancel: () => _cancelOrder(context),
        onSubmit: () => Navigator.of(context).pop(),
      ),
    );
  }
}
