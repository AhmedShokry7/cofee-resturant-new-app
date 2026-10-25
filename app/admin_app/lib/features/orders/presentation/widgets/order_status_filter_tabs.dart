import 'package:flutter/material.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_status_tabs.dart';

class OrderStatusFilterTabs extends StatelessWidget {
  const OrderStatusFilterTabs({
    super.key,
    required this.orders,
    required this.value,
    required this.onChanged,
  });

  final List<AdminOrder> orders;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) =>
      OrderStatusTabs(orders: orders, value: value, onChanged: onChanged);
}
