import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer_metrics.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';
import 'package:admin_app/shared/widgets/admin_metric_grid.dart';

class CustomerMetricsCards extends StatelessWidget {
  const CustomerMetricsCards({super.key, required this.metrics});

  final AdminCustomerMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData(
        label: S.customersAverageSpend,
        value: customerMoney(metrics.averageSpendCurrent),
        icon: AppIcons.wallet01,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
        isMoney: true,
        trend: metricPercentTrend(
          metrics.averageSpendCurrent,
          metrics.averageSpendPrevious,
        ),
      ),
      _MetricData(
        label: S.customersRepeatRate,
        value: customerPercent(metrics.repeatRateCurrent * 100),
        icon: AppIcons.repeat,
        iconBackground: AppColor.tintVioletSurface,
        iconColor: AppColor.tintVioletInk,
        trend: _pointTrend(
          metrics.repeatRateCurrent,
          metrics.repeatRatePrevious,
        ),
      ),
      _MetricData(
        label: S.customersNewThisMonth,
        value: customerCount(metrics.newCustomers),
        icon: AppIcons.userAdd01,
        iconBackground: AppColor.tintClaySurface,
        iconColor: AppColor.tintClayInk,
        trend: metricPercentTrend(
          metrics.newCustomers,
          metrics.previousNewCustomers,
        ),
      ),
      _MetricData(
        label: S.customersTotal,
        value: customerCount(metrics.totalCustomers),
        icon: AppIcons.userMultiple,
        iconBackground: AppColor.tintGreenSurface,
        iconColor: AppColor.trendPositive,
        trend: metricPercentTrend(
          metrics.totalCustomers,
          metrics.previousTotalCustomers,
        ),
      ),
    ];

    return AdminMetricGrid(
      children: [
        for (final card in cards)
          AdminMetricCard(
            label: card.label,
            value: card.value,
            icon: card.icon,
            iconBackground: card.iconBackground,
            iconColor: card.iconColor,
            changeLabel: card.trend?.label,
            isPositive: card.trend?.positive ?? true,
            isMoney: card.isMoney,
          ),
      ],
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    this.trend,
    this.isMoney = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final AdminMetricTrend? trend;
  final bool isMoney;
}

/// فرق نقطتين مئويّتين، مثل نسبة التكرار بين الشهر وشهره قبله.
AdminMetricTrend? _pointTrend(double current, double previous) {
  if (previous <= 0) return null;
  final change = (current - previous) * 100;
  return AdminMetricTrend(
    label: customerPercent(change.abs()),
    positive: change >= 0,
  );
}
