import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_customers_tile.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_metric_tile.dart';
import 'package:admin_app/shared/widgets/admin_metric_grid.dart';

/// أربع بلاطات تُقرأ أول ما تُفتح اللوحة: المال، وطلباته، وعملاؤه، ومتوسطه.
///
/// الأرقام كلها شَهرٌ كامل له سابقٌ يُقارَن به، لا يومٌ يتقلب مع كل طلب: اللوحة
/// تُقرأ مرة في الصباح وتُقفل، فتثبيتها على الشهر يجعل شاراتها ثابتة.
class DashboardMetricsCards extends StatelessWidget {
  const DashboardMetricsCards({super.key, required this.metrics});

  final AdminDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) => AdminMetricGrid(
    children: [
      DashboardMetricTile(
        label: S.dashboardAverageOrderValue,
        value: localizeDigits(formatAmount(metrics.averageOrderValue)),
        icon: AppIcons.coins01,
        surface: AppColor.adminWarningSurface,
        ink: AppColor.adminWarning,
        current: metrics.averageOrderValue,
        previous: metrics.yesterdayAverageOrderValue,
        caption: S.dashboardYesterday(
          localizeDigits(formatAmount(metrics.yesterdayAverageOrderValue)),
        ),
        isMoney: true,
        captionIsMoney: true,
      ),
      DashboardCustomersTile(metrics: metrics),
      DashboardMetricTile(
        label: S.dashboardNewOrders,
        value: localizeDigits(formatCount(metrics.monthOrders)),
        icon: AppIcons.receiptDollar,
        surface: AppColor.tintClaySurface,
        ink: AppColor.tintClayInk,
        current: metrics.monthOrders,
        previous: metrics.prevMonthOrders,
        caption: S.dashboardLastMonth(
          localizeDigits(formatCount(metrics.prevMonthOrders)),
        ),
      ),
      DashboardMetricTile(
        label: S.dashboardTotalSales,
        value: localizeDigits(formatAmount(metrics.monthRevenue)),
        icon: AppIcons.wallet01,
        surface: AppColor.tintGreenSurface,
        ink: AppColor.tintGreenInk,
        current: metrics.monthRevenue,
        previous: metrics.prevMonthRevenue,
        caption: S.dashboardLastMonth(
          localizeDigits(formatAmount(metrics.prevMonthRevenue)),
        ),
        isMoney: true,
        captionIsMoney: true,
      ),
    ],
  );
}
