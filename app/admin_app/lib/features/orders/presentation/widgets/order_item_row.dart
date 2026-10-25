import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_item_image.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_item_remove_button.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class OrderItemRow extends StatelessWidget {
  const OrderItemRow({
    super.key,
    required this.order,
    required this.item,
    required this.onRemove,
  });
  final AdminOrder order;
  final AdminOrderItem item;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            OrderItemImage(item: item),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productNameFor(AppLocale.instance.language),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${item.quantity} × ${formatAmount(item.unitPrice)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColor.greyColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (item.note?.trim().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.xs),
            child: Text(
              item.note!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: AppDimensions.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              formatAmount(item.lineTotal),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppDimensions.xs),
            const CurrencyIcon(size: 14),
            const SizedBox(width: AppDimensions.sm),
            OrderItemRemoveButton(order: order, item: item, onRemove: onRemove),
          ],
        ),
      ],
    ),
  );
}
