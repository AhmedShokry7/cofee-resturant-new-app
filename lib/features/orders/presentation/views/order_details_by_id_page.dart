import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/order_details_by_id/order_details_by_id_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_details_by_id_body.dart';

/// The order a notification named, opened from the id the row carries.
///
/// [OrderDetailsPage] draws frozen invoice lines, but a notification only names
/// the order, so this reads that one order and hands it on. A tap on the row in
/// the notifications list, on the banner of a message that arrived while the
/// app was open, and on a push that opened the app all land here, so the three
/// cannot disagree about where an order message goes.
class OrderDetailsByIdPage extends StatelessWidget {
  const OrderDetailsByIdPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OrderDetailsByIdCubit(
        repository: context.read<OrdersRepository>(),
        orderId: orderId,
      ),
      child: const OrderDetailsByIdBody(),
    );
  }
}
