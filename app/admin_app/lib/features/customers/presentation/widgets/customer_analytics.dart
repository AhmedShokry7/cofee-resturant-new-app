import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/customers/data/models/admin_customer.dart';

class CustomerAnalyticsPanel extends StatelessWidget {
  const CustomerAnalyticsPanel({super.key, required this.customers});

  final List<AdminCustomer> customers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = customers.length;
    final bought = customers.where((c) => c.ordersCount > 0).length;
    final notBought = total - bought;
    final vip = customers.where((c) => c.isVip).length;
    final blacklisted = customers.where((c) => c.isBlacklisted).length;

    final top = [...customers]
      ..sort((a, b) => b.ordersCount.compareTo(a.ordersCount));
    final top5 = top.take(5).where((c) => c.ordersCount > 0).toList();

    final colors = <Color>[
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(color: AppColor.recordBorder),
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Customer analytics',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          if (top5.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No orders yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    for (var i = 0; i < top5.length; i++)
                      PieChartSectionData(
                        value: top5[i].ordersCount.toDouble(),
                        title: '${top5[i].ordersCount}',
                        color: colors[i % colors.length],
                        radius: 60,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
              ),
            ),
          const SizedBox(height: AppDimensions.md),
          const Divider(),
          _StatRow(label: 'Total customers', value: '$total'),
          _StatRow(label: 'Bought', value: '$bought'),
          _StatRow(label: 'Not bought', value: '$notBought'),
          _StatRow(label: 'VIP', value: '$vip'),
          _StatRow(label: 'Blacklisted', value: '$blacklisted'),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
