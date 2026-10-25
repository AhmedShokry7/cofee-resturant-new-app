import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_detail_controller.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_customer_section.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_delivery_map.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_main_column.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_navigation.dart';

class OrderDetailBody extends StatelessWidget {
  const OrderDetailBody({
    super.key,
    required this.controller,
    required this.onStatusChanged,
    required this.onRemoveItem,
    required this.onAddProduct,
    required this.navigationOrders,
    required this.onSelectOrder,
  });
  final OrderDetailController controller;
  final ValueChanged<String> onStatusChanged, onRemoveItem;
  final VoidCallback onAddProduct;
  final List<AdminOrder> navigationOrders;
  final ValueChanged<String> onSelectOrder;

  @override
  Widget build(BuildContext context) {
    final order = controller.order;
    final wide = MediaQuery.sizeOf(context).width >= 1120;
    final customer = OrderCustomerSection(
      order: order,
      customerDetails: controller.customerDetails,
      isLoadingCustomerDetails: controller.customerDetailsLoading,
      customerDetailsFailed: controller.customerDetailsFailed,
      previousOrders: controller.previousOrders,
      onOpenPreviousOrder: (value) => onSelectOrder(value.id),
    );
    final map =
        controller.deliveryLatitude != null &&
            controller.deliveryLongitude != null
        ? OrderDeliveryMap(
            latitude: controller.deliveryLatitude!,
            longitude: controller.deliveryLongitude!,
            branchLatitude: controller.branchLatitude,
            branchLongitude: controller.branchLongitude,
          )
        : null;
    final main = OrderDetailMainColumn(
      controller: controller,
      onStatusChanged: onStatusChanged,
      onRemoveItem: onRemoveItem,
      onAddProduct: onAddProduct,
      customer: wide ? null : customer,
      deliveryMap: wide ? null : map,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrderDetailNavigation(
          orders: navigationOrders,
          orderId: order.id,
          onSelect: onSelectOrder,
        ),
        const SizedBox(height: AppDimensions.md),
        if (!wide)
          main
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: main),
              const SizedBox(width: AppDimensions.lg),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    customer,
                    if (map != null) ...[
                      const SizedBox(height: AppDimensions.md),
                      map,
                    ],
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
