import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/presentation/manager/order_cancellation/order_cancellation_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_action_bottom_bar.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/track_order_page_body.dart';

/// The tracking screen, with the one write it offers: cancelling this order.
///
/// Leaving with `true` tells whoever opened it that the order is now cancelled,
/// so the list or the details page above can drop the row it is still holding.
class TrackOrderView extends StatelessWidget {
  const TrackOrderView({super.key, required this.order});

  final OrderItemModel order;

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderCancellationCubit, OrderCancellationState>(
      listenWhen: (previous, current) =>
          current.cancelled ||
          (current.error != null && current.error != previous.error),
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        if (state.cancelled) {
          navigator.pop(true);
          messenger.showSnackBar(SnackBar(content: Text(S.orderCancelled)));
          return;
        }
        messenger.showSnackBar(SnackBar(content: Text(state.errorCopy!)));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(S.trackOrder)),
        body: TrackOrderPageBody(order: order),
        bottomNavigationBar:
            BlocBuilder<OrderCancellationCubit, OrderCancellationState>(
              builder: (context, state) => OrderActionBottomBar(
                cancelText: S.cancelOrder,
                submitText: S.back,
                // The write is on its way: a second tap would ask the server to
                // cancel an order that is already cancelled.
                onCancel: state.isCancelling
                    ? null
                    : () => context.read<OrderCancellationCubit>().cancel(),
                isCancelling: state.isCancelling,
                onSubmit: () => Navigator.of(context).pop(),
              ),
            ),
      ),
    );
  }
}
