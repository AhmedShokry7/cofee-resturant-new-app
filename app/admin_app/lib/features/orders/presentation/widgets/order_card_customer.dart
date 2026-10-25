import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';

class OrderCardCustomer extends StatelessWidget {
  const OrderCardCustomer({super.key, required this.order});
  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final status = OrderStatusView.of(order.status);
    return Row(
      children: [
        AdminAvatarImage(url: order.customerAvatarUrl, size: 48),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Text(
            order.customerName ?? S.ordersUnknownCustomer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        AdminStatusBadge(label: status.label, color: status.color),
      ],
    );
  }
}
