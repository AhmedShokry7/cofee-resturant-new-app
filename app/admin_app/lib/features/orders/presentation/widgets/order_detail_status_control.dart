import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';

class OrderDetailStatusControl extends StatelessWidget {
  const OrderDetailStatusControl({
    super.key,
    required this.order,
    required this.saving,
    required this.onChanged,
  });
  final AdminOrder order;
  final bool saving;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final statuses = OrderStatusView.allCodes;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: statuses.contains(order.status) ? order.status : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: S.changeStatus),
            items: [
              for (final code in statuses)
                DropdownMenuItem(
                  value: code,
                  child: Text(OrderStatusView.of(code).label),
                ),
            ],
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) onChanged(value);
                  },
          ),
        ),
        if (saving) ...[
          const SizedBox(width: AppDimensions.sm),
          const SizedBox(
            width: AppDimensions.spinnerSize,
            height: AppDimensions.spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: AppDimensions.spinnerStroke,
            ),
          ),
        ],
      ],
    );
  }
}
