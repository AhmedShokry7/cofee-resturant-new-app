import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/orders_page_body.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  static const routeName = "ordersRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Orders")),
      body: BlocProvider(
        create: (context) => OrdersCubit(
          repository: context.read<OrdersRepository>(),
        ),
        child: const OrdersPageBody(),
      ),
    );
  }
}
