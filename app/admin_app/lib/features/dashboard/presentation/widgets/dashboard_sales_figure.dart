import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_insights.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_sales_amount.dart';
import 'package:admin_app/shared/widgets/admin_chart_legend.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart.dart';

/// منحنى المدى المختار: ماله ونسبته وأيامه ومفتاحه.
///
/// المال مجموع أيام أرسلتها القاعدة كاملة، والنسبة من رقمي القاعدة (المدى وما
/// قبله) فتُحسب هنا وتُطبع في `DashboardSalesAmount` وحده. والمحور الرأسي يُقسَم
/// على قمة النافذة نفسها لا على رقم مريح للعين، وإلا بدت أعلى ليلة في منتصف
/// اللوحة.
class DashboardSalesFigure extends StatelessWidget {
  const DashboardSalesFigure({
    super.key,
    required this.metrics,
    required this.rangeDays,
  });

  final AdminDashboardMetrics metrics;
  final int rangeDays;

  List<AdminTrendPoint> get _points => [
    for (final day in metrics.salesWindow(rangeDays))
      AdminTrendPoint(label: dashboardDayLabel(day.date), value: day.revenue),
  ];

  /// النسبة من رقمي القاعدة، و`null` حين لا أساس: لا مقارنة تُخترع.
  AdminMetricTrend? get _trend => rangeDays == dashboardMonthRangeDays
      ? metricPercentTrend(metrics.monthRevenue, metrics.prevMonthRevenue)
      : metricPercentTrend(metrics.weekRevenue, metrics.prevWeekRevenue);

  /// خمس تسميات من قمة النافذة إلى صفرها، تنزل على خطوط الشبكة نفسها.
  List<String> get _valueLabels {
    final peak = metrics.peakSalesValue(rangeDays);
    return [
      for (var step = 4; step >= 0; step--) dashboardAxisValue(peak * step / 4),
    ];
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DashboardSalesAmount(
        amount: metrics.revenueWindow(rangeDays),
        trend: _trend,
      ),
      const SizedBox(height: AppSizes.px12),
      AdminTrendChart(points: _points, valueLabels: _valueLabels),
      const SizedBox(height: AppSizes.px8),
      AdminChartLegend(
        label: S.dashboardSalesLegend,
        color: AppColor.primaryColor,
      ),
    ],
  );
}
