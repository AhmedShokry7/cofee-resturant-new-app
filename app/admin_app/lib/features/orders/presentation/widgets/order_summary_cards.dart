import 'package:flutter/material.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric_data.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class OrderSummaryCards extends StatelessWidget {
  const OrderSummaryCards({
    super.key,
    required this.orders,
    this.branchId = '',
  });

  final List<AdminOrder> orders;
  final String branchId;

  @override
  Widget build(BuildContext context) {
    final metrics = OrderSummaryMetricDataBuilder.build(orders, branchId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        final columns = availableWidth < 900 ? 2 : 4;

        const spacing = 13.0;
        final cardWidth = (availableWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: cardWidth,
                child: AdminMetricCard(
                  label: metric.label,
                  value: metric.value,
                  icon: metric.icon,
                  iconBackground: metric.iconBackground,
                  iconColor: metric.iconColor,
                  changeLabel: metric.changeLabel,
                  isPositive: metric.isPositive,
                  isMoney: metric.isMoney,
                ),
              ),
          ],
        );
      },
    );
  }
}
