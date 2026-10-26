import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_dropdown.dart';

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
          child: OrderFilterDropdown(
            key: ValueKey(order.status),
            label: S.changeStatus,
            value: statuses.contains(order.status) ? order.status : '',
            items: [
              for (final code in statuses)
                DropdownMenuItem(
                  value: code,
                  child: Text(OrderStatusView.of(code).label),
                ),
            ],
            enabled: !saving,
            onChanged: onChanged,
          ),
        ),
        if (saving) ...[
          const SizedBox(width: AppSpacing.sm),
          const SizedBox(
            width: AppSizes.px18,
            height: AppSizes.px18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColor.adminAccent,
            ),
          ),
        ],
      ],
    );
  }
}
