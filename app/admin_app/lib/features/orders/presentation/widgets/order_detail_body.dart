import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_detail_controller.dart';
import 'package:admin_app/features/orders/presentation/widgets/customer_previous_orders.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_actions.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_customer_section.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_delivery_map.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_header.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_navigation.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_stats.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_fulfillment_section.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_items_list.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_payment_section.dart';

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
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1080;

    final items = OrderItemsList(
      order: order,
      canEdit: controller.canManage,
      onRemoveItem: onRemoveItem,
      onAddProduct: onAddProduct,
    );
    final payment = OrderPaymentSection(
      order: order,
      saving: controller.saving,
      onPaymentStatusChanged: controller.canManage
          ? (value) => changePaymentStatus(context, controller, value)
          : null,
    );
    final customer = OrderCustomerSection(
      order: order,
      customerDetails: controller.customerDetails,
    );
    final previousOrders = CustomerPreviousOrders(
      orders: controller.previousOrders,
      loading: controller.customerDetailsLoading,
      failed: controller.customerDetailsFailed,
      onOpen: (value) => onSelectOrder(value.id),
    );
    final fulfillment = OrderFulfillmentSection(order: order);
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

    final main = <Widget>[
      items,
      const SizedBox(height: AppSizes.px12),
      payment,
    ];
    final side = <Widget>[
      customer,
      const SizedBox(height: AppSizes.px12),
      previousOrders,
      const SizedBox(height: AppSizes.px12),
      fulfillment,
      if (map != null) ...[const SizedBox(height: AppSizes.px12), map],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrderDetailNavigation(
          orders: navigationOrders,
          orderId: order.id,
          onSelect: onSelectOrder,
        ),
        const SizedBox(height: AppSpacing.md),
        OrderDetailHeader(
          order: order,
          saving: controller.saving,
          canChangeStatus: controller.canManage,
          allowedStatuses: controller.statusRules?.allowedFor(order.status),
          onStatusChanged: onStatusChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        OrderDetailStats(order: order),
        const SizedBox(height: AppSpacing.lg),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: main,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: side,
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              items,
              const SizedBox(height: AppSizes.px12),
              payment,
              const SizedBox(height: AppSizes.px12),
              customer,
              const SizedBox(height: AppSizes.px12),
              previousOrders,
              const SizedBox(height: AppSizes.px12),
              fulfillment,
              if (map != null) ...[const SizedBox(height: AppSizes.px12), map],
            ],
          ),
      ],
    );
  }
}
