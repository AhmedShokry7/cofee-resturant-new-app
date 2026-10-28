import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filtering.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_status_tab.dart';

class OrderStatusTabs extends StatelessWidget {
  const OrderStatusTabs({
    super.key,
    required this.orders,
    required this.value,
    required this.onChanged,
  });

  final List<AdminOrder> orders;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, String)>[
      ('', S.ordersAll),
      ('processing', S.ordersPreparing),
      ('shipped', S.orderShipped),
      ('completed', S.statusCompleted),
      ('cancelled', S.statusCancelled),
    ];

    return SizedBox(
      height: AppSizes.px36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final (code, label) = tabs[index];
          final isSelected = value == code;

          final count = filterOrders(orders, status: code).length;
          return OrderStatusTab(
            code: code,
            label: label,
            count: count,
            selected: isSelected,
            onTap: () => onChanged(code),
          );
        },
      ),
    );
  }
}
