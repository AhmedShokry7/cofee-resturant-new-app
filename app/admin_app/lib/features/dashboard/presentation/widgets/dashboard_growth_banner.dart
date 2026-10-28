import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_growth_headline.dart';
import 'package:admin_app/shared/widgets/admin_icon_badge.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// شريط النمو فوق اللوحة: جملة واحدة تفرح برقم حقيقي، أو لا جملة.
///
/// المديح يُقال حين يكون الارتفاع مقاسًا من رقمي القاعدة لا تقديرًا؛ فمع انخفاض
/// أو بلا أساس يعود الشريط فراغًا — تهنئة في يوم سيئ أسوأ من غيابها. والمدى
/// المختار يحدد الفترة التي يُنسب إليها الرقم.
class DashboardGrowthBanner extends StatelessWidget {
  const DashboardGrowthBanner({
    super.key,
    required this.metrics,
    required this.rangeDays,
  });

  final AdminDashboardMetrics metrics;
  final int rangeDays;

  bool get _isMonth => rangeDays == dashboardMonthRangeDays;

  /// النسبة من رقمي القاعدة، و`null` حين لا أساس: لا مديح بغير مقارنة.
  AdminMetricTrend? get _trend => _isMonth
      ? metricPercentTrend(metrics.monthRevenue, metrics.prevMonthRevenue)
      : metricPercentTrend(metrics.weekRevenue, metrics.prevWeekRevenue);

  String get _period =>
      _isMonth ? S.dashboardVsLastMonth : S.dashboardWeeklyGrowth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trend = _trend;
    if (trend == null || !trend.positive) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.px16,
        vertical: AppSizes.px12,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.trendPositive,
          AppColor.adminAccentSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DashboardGrowthHeadline(
              percent: trend.label,
              period: _period,
            ),
          ),
          const SizedBox(width: AppSizes.px12),
          const AdminIconBadge(
            icon: AppIcons.sparkles,
            color: AppColor.trendPositive,
            surface: AppColor.tintGreenSurface,
          ),
        ],
      ),
    );
  }
}
