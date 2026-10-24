import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_detail_controller.dart';
import 'package:admin_app/features/orders/presentation/models/order_edit_rules.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_actions.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_customer_section.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_delivery_map.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_header.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_fulfillment_section.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_items_list.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_payment_section.dart';

/// Composes the order details in a clear, consistent reading order.
class OrderDetailBody extends StatelessWidget {
  const OrderDetailBody({
    super.key,
    required this.controller,
    required this.onStatusChanged,
    required this.onRemoveItem,
    required this.onAddProduct,
  });

  final OrderDetailController controller;
  final ValueChanged<String> onStatusChanged;
  final void Function(String itemId) onRemoveItem;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    final order = controller.order;
    final latitude = controller.deliveryLatitude;
    final longitude = controller.deliveryLongitude;
    final canEditItems = OrderEditRules.canEditItems(order);
    final hasMap = latitude != null && longitude != null;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Order identity and status actions.
        OrderDetailHeader(
          order: order,
          saving: controller.saving,
          onStatusChanged: onStatusChanged,
        ),

        const SizedBox(height: AppDimensions.lg),

        // Customer details (narrow screens keep them in the main column).
        if (!wide) ...[
          OrderCustomerSection(
            order: order,
            customerDetails: controller.customerDetails,
            isLoadingCustomerDetails: controller.customerDetailsLoading,
          ),
          const SizedBox(height: AppDimensions.md),
        ],

        // Branch, fulfilment method and delivery information.
        OrderFulfillmentSection(order: order),

        const SizedBox(height: AppDimensions.md),

        // Products and their management actions.
        OrderItemsList(
          order: order,
          onRemoveItem: onRemoveItem,
        ),

        const SizedBox(height: AppDimensions.sm),

        _AddProductButton(
          enabled: canEditItems,
          onPressed: onAddProduct,
        ),

        const SizedBox(height: AppDimensions.lg),

        // Authoritative payment status and financial totals.
        OrderPaymentSection(
          order: order,
          saving: controller.saving,
          onPaymentStatusChanged: (value) =>
              changePaymentStatus(context, controller, value),
        ),

        if (hasMap && !wide) ...[
          const SizedBox(height: AppDimensions.md),
          OrderDeliveryMap(
            latitude: latitude,
            longitude: longitude,
            branchLatitude: controller.branchLatitude,
            branchLongitude: controller.branchLongitude,
          ),
        ],
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: content),
          const SizedBox(width: AppDimensions.lg),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Customer information card at the top of the sidebar.
                OrderCustomerSection(
                  order: order,
                  customerDetails: controller.customerDetails,
                  isLoadingCustomerDetails: controller.customerDetailsLoading,
                ),
                if (hasMap) ...[
                  const SizedBox(height: AppDimensions.md),
                  OrderDeliveryMap(
                    latitude: latitude,
                    longitude: longitude,
                    branchLatitude: controller.branchLatitude,
                    branchLongitude: controller.branchLongitude,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return content;
  }
}

class _AddProductButton extends StatelessWidget {
  const _AddProductButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? S.addProduct : S.orderCannotBeEdited,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FilledButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: const Icon(
            HugeIcons.strokeRoundedAdd01,
            size: AppDimensions.xl,
          ),
          label: Text(S.addProduct),
        ),
      ),
    );
  }
}
