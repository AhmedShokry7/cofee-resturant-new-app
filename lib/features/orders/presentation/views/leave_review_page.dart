import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/review/review_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/leave_review_view.dart';

/// The rating the customer leaves for one product of a finished order.
class LeaveReviewPage extends StatelessWidget {
  const LeaveReviewPage({super.key, required this.order});

  static const routeName = "leaveReviewRoute";

  final OrderItemModel order;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ReviewCubit(repository: context.read<OrdersRepository>()),
      child: LeaveReviewView(order: order),
    );
  }
}
