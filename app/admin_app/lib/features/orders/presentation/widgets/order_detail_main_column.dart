import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_detail_controller.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_add_product_button.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_customer_section.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_delivery_map.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_header.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_fulfillment_section.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_items_list.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_payment_section.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_actions.dart';

class OrderDetailMainColumn extends StatelessWidget {
  const OrderDetailMainColumn({
    super.key,
    required this.controller,
    required this.onStatusChanged,
    required this.onRemoveItem,
    required this.onAddProduct,
    this.customer,
    this.deliveryMap,
  });
  final OrderDetailController controller;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onRemoveItem;
  final VoidCallback onAddProduct;
  final OrderCustomerSection? customer;
  final OrderDeliveryMap? deliveryMap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OrderDetailHeader(
        order: controller.order,
        saving: controller.saving,
        onStatusChanged: onStatusChanged,
      ),
      if (customer != null) ...[
        const SizedBox(height: AppDimensions.md),
        customer!,
      ],
      const SizedBox(height: AppDimensions.md),
      OrderFulfillmentSection(order: controller.order),
      const SizedBox(height: AppDimensions.md),
      OrderItemsList(order: controller.order, onRemoveItem: onRemoveItem),
      const SizedBox(height: AppDimensions.sm),
      OrderAddProductButton(order: controller.order, onPressed: onAddProduct),
      const SizedBox(height: AppDimensions.lg),
      OrderPaymentSection(
        order: controller.order,
        saving: controller.saving,
        onPaymentStatusChanged: (value) =>
            changePaymentStatus(context, controller, value),
      ),
      if (deliveryMap != null) ...[
        const SizedBox(height: AppDimensions.md),
        deliveryMap!,
      ],
    ],
  );
}
