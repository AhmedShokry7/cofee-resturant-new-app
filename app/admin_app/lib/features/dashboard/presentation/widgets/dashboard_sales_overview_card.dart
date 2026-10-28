import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_insights.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_sales_figure.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// نظرة على المبيعات في المدى الذي يختاره الأدمن من رأس البطاقة.
///
/// السلسلة كاملة ثلاثون يومًا تصل في `sales_series` من استجابة اللوحة،
/// والاختيار هنا نافذة عرض فقط: لا تُسأل القاعدة عند التبديل، فلا يتأخر المفتاح
/// ولا يقرأ الأدمن رقمين مختلفين لليوم نفسه.
class DashboardSalesOverviewCard extends StatelessWidget {
  const DashboardSalesOverviewCard({
    super.key,
    required this.metrics,
    required this.rangeDays,
    required this.onRangeChanged,
  });

  final AdminDashboardMetrics metrics;
  final int rangeDays;
  final ValueChanged<int> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      localizeDigits(S.dashboardRangeWeek),
      localizeDigits(S.dashboardRangeMonth),
    ];
    return AdminSectionCard(
      title: S.dashboardSalesOverviewTitle,
      subtitle: S.dashboardSalesOverviewSubtitle,
      trailing: AdminSegmentedControl(
        options: options,
        selected: rangeDays == dashboardWeekRangeDays
            ? options.first
            : options.last,
        onChanged: (value) => onRangeChanged(
          value == options.first
              ? dashboardWeekRangeDays
              : dashboardMonthRangeDays,
        ),
      ),
      child: metrics.revenueWindow(rangeDays) <= 0
          ? AdminEmptyState(
              icon: AppIcons.chartLineData01,
              message: S.dashboardSalesEmpty,
            )
          : DashboardSalesFigure(metrics: metrics, rangeDays: rangeDays),
    );
  }
}
