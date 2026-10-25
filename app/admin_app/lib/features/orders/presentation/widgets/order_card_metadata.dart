import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';

class OrderCardMetadata extends StatelessWidget {
  const OrderCardMetadata({super.key, required this.order});
  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final fulfillment = OrderFulfillmentView.of(order.fulfillmentType);
    final branch = order.branchNameFor(AppLocale.instance.language);
    final method = fulfillment.isDelivery || branch.isEmpty
        ? fulfillment.label
        : '${fulfillment.label} • $branch';
    return Wrap(
      spacing: AppDimensions.md,
      runSpacing: AppDimensions.xs,
      children: [
        _meta(HugeIcons.strokeRoundedClock03, formatDateTime(order.placedAt)),
        _meta(HugeIcons.strokeRoundedDeliveryTruck01, method),
        _meta(
          HugeIcons.strokeRoundedMoney03,
          OrderPaymentStatusView.of(order.paymentStatus).label,
          OrderPaymentStatusView.of(order.paymentStatus).color,
        ),
      ],
    );
  }

  Widget _meta(dynamic icon, String label, [Color? color]) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      HugeIcon(icon: icon, size: 15, color: color ?? AppColor.greyColor),
      const SizedBox(width: AppDimensions.xs),
      Text(
        label,
        style: TextStyle(color: color ?? AppColor.greyColor, fontSize: 12),
      ),
    ],
  );
}
