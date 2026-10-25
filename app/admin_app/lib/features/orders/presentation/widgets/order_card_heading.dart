import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class OrderCardHeading extends StatelessWidget {
  const OrderCardHeading({super.key, required this.order, this.onChangeStatus});
  final AdminOrder order;
  final ValueChanged<String>? onChangeStatus;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          '#${order.orderNumber}',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      Text(formatAmount(order.grandTotal)),
      const SizedBox(width: 4),
      const CurrencyIcon(size: 14),
      if (onChangeStatus != null)
        PopupMenuButton<String>(
          tooltip: S.changeStatus,
          onSelected: onChangeStatus,
          itemBuilder: (_) => [
            for (final code in OrderStatusView.allCodes)
              PopupMenuItem(
                value: code,
                child: Text(OrderStatusView.of(code).label),
              ),
          ],
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedMoreHorizontalCircle01,
            size: 18,
            color: AppColor.greyColor,
          ),
        ),
    ],
  );
}
