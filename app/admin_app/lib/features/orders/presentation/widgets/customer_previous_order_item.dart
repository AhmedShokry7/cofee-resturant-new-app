import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class CustomerPreviousOrderItem extends StatelessWidget {
  const CustomerPreviousOrderItem({super.key, required this.order, this.onTap});
  final AdminOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = OrderStatusView.of(order.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '#${order.orderNumber}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(formatAmount(order.grandTotal)),
                    const SizedBox(width: 4),
                    const CurrencyIcon(size: 14),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Row(
                  children: [
                    AdminStatusBadge(label: status.label, color: status.color),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        formatDateTime(order.placedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
