import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_highlight_line.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

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
    final dark = theme.brightness == Brightness.dark;
    final trend = _trend;
    if (trend == null || !trend.positive) return const SizedBox.shrink();
    // شريط النمو شريط متدرّج بلون الهوية: البشكلة تُقرأ فرحًا قبل الرقم.
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.px18,
        vertical: AppSizes.px14,
      ),
      decoration: BoxDecoration(
        gradient: dark
            ? null
            : LinearGradient(
                colors: [
                  AppColor.primaryColor,
                  Color.lerp(AppColor.primaryColor, AppColor.whiteColor, .18)!,
                ],
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
        color: dark ? AppColor.primaryColor.withValues(alpha: .16) : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: dark
              ? AppColor.primaryColor.withValues(alpha: .45)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark
                  ? AppColor.primaryColor.withValues(alpha: .28)
                  : AppColor.whiteColor.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              AppIcons.sparkles,
              size: 20,
              color: dark ? AppColor.secondaryColor : AppColor.whiteColor,
            ),
          ),
          const SizedBox(width: AppSizes.px14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.dashboardGrowthHeadline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? AppColor.darkText : AppColor.whiteColor,
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                AdminHighlightLine(
                  before: S.dashboardGrowthUp,
                  value: trend.label,
                  after: '$_period. ${S.dashboardGrowthKeepGoing}',
                  valueColor: dark
                      ? AppColor.secondaryColor
                      : AppColor.whiteColor,
                  style: TextStyle(
                    color: dark
                        ? AppColor.darkTextSecondary
                        : AppColor.whiteColor.withValues(alpha: .88),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
