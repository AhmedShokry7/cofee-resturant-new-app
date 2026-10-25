import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/customer_previous_order_item.dart';

class CustomerPreviousOrders extends StatelessWidget {
  const CustomerPreviousOrders({
    super.key,
    required this.orders,
    required this.loading,
    required this.failed,
    this.onOpen,
  });
  final List<AdminOrder> orders;
  final bool loading, failed;
  final ValueChanged<AdminOrder>? onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedShoppingBag01,
            size: 17,
            color: AppColor.greyColor,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              S.ordersCustomerHistory,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${orders.length}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      const SizedBox(height: AppDimensions.sm),
      if (loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.md),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      else if (orders.isEmpty)
        Text(
          failed ? S.customerHistoryLoadFailed : S.ordersNoPreviousOrders,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColor.greyColor),
        )
      else
        for (final order in orders.take(5))
          CustomerPreviousOrderItem(
            order: order,
            onTap: onOpen == null ? null : () => onOpen!(order),
          ),
    ],
  );
}
