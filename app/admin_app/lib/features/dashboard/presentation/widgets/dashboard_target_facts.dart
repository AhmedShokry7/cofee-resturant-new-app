import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_insights.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_gap.dart';
import 'package:admin_app/shared/widgets/admin_labeled_value.dart';
import 'package:admin_app/shared/widgets/admin_progress_bar.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// رقما الهدف والمُحقَّق أمام بعضهما، وشريطٌ يقيس أحدهما بالآخر.
///
/// النسبة تُقال مرة في الحلقة، وهنا يُطبع أساسها: رقمٌ واحد بلا مقارَنته يترك
/// الأدمن يسأل «من كم؟». والشريط لا يتجاوز آخره، والتخطّي يُقال بنصّ تحته لا
/// بشريط ينساب خارج البطاقة.
class DashboardTargetFacts extends StatelessWidget {
  const DashboardTargetFacts({super.key, required this.metrics});

  final AdminDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = metrics.monthlyRevenueTarget ?? 0;
    final progress = metrics.targetProgress ?? 0;
    final reached = metrics.monthRevenue >= target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AdminLabeledValue(
                label: S.dashboardTargetTitle,
                child: _amount(theme, target),
              ),
            ),
            Expanded(
              child: AdminLabeledValue(
                label: S.dashboardCurrentSales,
                child: _amount(theme, metrics.monthRevenue),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.px14),
        AdminProgressBar(
          value: progress,
          height: AppSizes.px6,
          color: reached ? AppColor.trendPositive : AppColor.adminAccent,
        ),
        const SizedBox(height: AppSizes.px10),
        DashboardTargetGap(
          reached: reached,
          remaining: target - metrics.monthRevenue,
        ),
      ],
    );
  }

  Widget _amount(ThemeData theme, double value) => Text(
    formatMoneyWithCurrency(value),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: adminAmountColor(theme),
      fontSize: AppFontSizes.size10,
      fontWeight: AppFontWeights.semiBold,
      height: AppTextHeights.line1_4,
    ),
  );
}
