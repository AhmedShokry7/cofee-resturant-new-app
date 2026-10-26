import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_add_product_button.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_item_row.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderItemsList extends StatelessWidget {
  const OrderItemsList({
    super.key,
    required this.order,
    required this.onRemoveItem,
    this.onAddProduct,
  });

  final AdminOrder order;
  final ValueChanged<String> onRemoveItem;
  final VoidCallback? onAddProduct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminSectionCard(
      title: S.orderItemsLabel,
      count: order.items.length,
      trailing: onAddProduct == null
          ? null
          : OrderAddProductButton(order: order, onPressed: onAddProduct!),
      child: order.items.isEmpty
          ? Text(
              S.noOrderItems,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size11,
                height: AppTextHeights.line1_5,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < order.items.length; index++) ...[
                  if (index > 0)
                    Divider(height: 17, color: adminRowBorderColor(theme)),
                  OrderItemRow(
                    order: order,
                    item: order.items[index],
                    onRemove: onRemoveItem,
                  ),
                ],
              ],
            ),
    );
  }
}
