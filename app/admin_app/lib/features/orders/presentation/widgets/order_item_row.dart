import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_item_image.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_item_remove_button.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final note = item.note?.trim() ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderItemImage(item: item),
        const SizedBox(width: AppSizes.px10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productNameFor(AppLocale.instance.language),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminBodyColor(theme),
                  fontSize: AppFontSizes.size11_5,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_5,
                ),
              ),
              const SizedBox(height: AppSizes.px2),
              Row(
                children: [
                  Text(
                    '${orderCount(item.quantity)} × ${orderMoney(item.unitPrice)}',
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size10,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                  const SizedBox(width: AppSizes.px4),
                  const CurrencyIcon(size: 10),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: AppSizes.px4),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminSubtleColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    fontStyle: FontStyle.italic,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AdminMoneyText(
              value: item.lineTotal,
              fontSize: AppFontSizes.size11_5,
              color: dark ? AppColor.darkText : AppColor.adminAmount,
              formatter: orderMoney,
            ),
            const SizedBox(height: AppSizes.px2),
            OrderItemRemoveButton(order: order, item: item, onRemove: onRemove),
          ],
        ),
      ],
    );
  }
}
