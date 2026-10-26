import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer_metrics.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class CustomerMetricsCards extends StatelessWidget {
  const CustomerMetricsCards({super.key, required this.metrics});

  final AdminCustomerMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData(
        label: S.customersAverageSpend,
        value: customerMoneyWithCurrency(metrics.averageSpendCurrent),
        icon: AppIcons.wallet01,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
        trend: _percentTrend(
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
        trend: _percentTrend(
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
        trend: _percentTrend(
          metrics.totalCustomers,
          metrics.previousTotalCustomers,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < AppBreakpoints.wideLayout ? 2 : 4;
        const spacing = 13.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: AdminMetricCard(
                  label: card.label,
                  value: card.value,
                  icon: card.icon,
                  iconBackground: card.iconBackground,
                  iconColor: card.iconColor,
                  changeLabel: card.trend?.label,
                  isPositive: card.trend?.positive ?? true,
                ),
              ),
          ],
        );
      },
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
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final _Trend? trend;
}

class _Trend {
  const _Trend({required this.label, required this.positive});

  final String label;
  final bool positive;
}

_Trend? _percentTrend(num current, num previous) {
  if (previous <= 0) return null;
  final change = (current - previous) / previous * 100;
  return _Trend(label: customerPercent(change.abs()), positive: change >= 0);
}

_Trend? _pointTrend(double current, double previous) {
  if (previous <= 0) return null;
  final change = (current - previous) * 100;
  return _Trend(label: customerPercent(change.abs()), positive: change >= 0);
}
