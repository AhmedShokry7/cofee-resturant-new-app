import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_detail_controller.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_actions.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_app_bar.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_body.dart';

/// The whole content of one order, editable by the admin while the backend
/// still allows it.
class OrderDetailsPage extends StatefulWidget {
  const OrderDetailsPage({
    super.key,
    required this.order,
    this.cubit,
    this.navigationOrders = const [],
  });

  final AdminOrder order;
  final AdminOrderCubit? cubit;
  final List<AdminOrder> navigationOrders;

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

  Future<void> _selectOrder(String orderId) async {
    try {
      final found = await _controller.openOrder(orderId);
      if (!found && mounted) _showMessage(S.orderNotFound);
    } catch (_) {
      if (mounted) _showMessage(S.orderActionFailed);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final order = _controller.order;
        final narrow =
            MediaQuery.sizeOf(context).width < AppBreakpoints.pageCanvas;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                OrderDetailAppBar(
                  orderNumber: order.orderNumber,
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: narrow
                          ? AppDimensions.pageFrameGutterNarrow
                          : AppDimensions.pageFrameGutterWide,
                      vertical: narrow
                          ? AppDimensions.pageFrameInnerTopNarrow
                          : AppDimensions.pageFrameInnerTopWide,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppDimensions.detailMaxContentWidth,
                        ),
                        child: OrderDetailBody(
                          controller: _controller,
                          navigationOrders: widget.navigationOrders,
                          onSelectOrder: _selectOrder,
                          onStatusChanged: (value) =>
                              changeOrderStatus(context, _controller, value),
                          onRemoveItem: (itemId) =>
                              removeOrderLine(context, _controller, itemId),
                          onAddProduct: () =>
                              addProductToOrder(context, _controller),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
