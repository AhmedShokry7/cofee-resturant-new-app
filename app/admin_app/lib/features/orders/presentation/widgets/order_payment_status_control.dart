import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';

class OrderPaymentStatusControl extends StatelessWidget {
  const OrderPaymentStatusControl({
    super.key,
    required this.order,
    required this.saving,
    this.onChanged,
  });
  final AdminOrder order;
  final bool saving;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final view = OrderPaymentStatusView.of(order.paymentStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.paymentStatusLabelTitle,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColor.greyColor),
              ),
            ),
            AdminStatusBadge(label: view.label, color: view.color),
          ],
        ),
        if (onChanged != null) ...[
          const SizedBox(height: AppDimensions.sm),
          DropdownButtonFormField<String>(
            initialValue:
                OrderPaymentStatusView.allCodes.contains(order.paymentStatus)
                ? order.paymentStatus
                : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: S.changePaymentStatus),
            items: [
              for (final code in OrderPaymentStatusView.allCodes)
                DropdownMenuItem(
                  value: code,
                  child: Text(OrderPaymentStatusView.of(code).label),
                ),
            ],
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) onChanged!(value);
                  },
          ),
          if (saving)
            const Padding(
              padding: EdgeInsets.only(top: AppDimensions.xs),
              child: LinearProgressIndicator(),
            ),
        ],
      ],
    );
  }
}
