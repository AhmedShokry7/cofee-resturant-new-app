import 'package:flutter/material.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_item_row.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_section_card.dart';

class OrderItemsList extends StatelessWidget {
  const OrderItemsList({
    super.key,
    required this.order,
    required this.onRemoveItem,
  });
  final AdminOrder order;
  final ValueChanged<String> onRemoveItem;

  @override
  Widget build(BuildContext context) => OrderSectionCard(
    title: S.ordersItems,
    child: order.items.isEmpty
        ? Text(
            S.noOrderItems,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColor.greyColor),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in order.items)
                OrderItemRow(order: order, item: item, onRemove: onRemoveItem),
            ],
          ),
  );
}
