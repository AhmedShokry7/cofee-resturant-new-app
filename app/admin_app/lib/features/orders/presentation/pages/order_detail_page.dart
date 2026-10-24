import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_detail_controller.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_actions.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_body.dart';

/// The whole content of one order, editable by the admin while the backend
/// still allows it.
class OrderDetailsPage extends StatefulWidget {
  const OrderDetailsPage({super.key, required this.order, this.cubit});

  final AdminOrder order;
  final AdminOrderCubit? cubit;

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late final AdminOrderCubit _cubit;
  late final bool _ownsCubit;
  late final OrderDetailController _controller;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminOrderCubit();
    _controller = OrderDetailController(cubit: _cubit, order: widget.order)
      ..loadProducts();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final order = _controller.order;
        return Scaffold(
          appBar: AppBar(title: Text('#${order.orderNumber}')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.pageHorizontalPadding),
            child: OrderDetailBody(
              controller: _controller,
              onStatusChanged: (value) =>
                  changeOrderStatus(context, _controller, value),
              onRemoveItem: (itemId) =>
                  removeOrderLine(context, _controller, itemId),
              onAddProduct: () => addProductToOrder(context, _controller),
            ),
          ),
        );
      },
    );
  }
}
