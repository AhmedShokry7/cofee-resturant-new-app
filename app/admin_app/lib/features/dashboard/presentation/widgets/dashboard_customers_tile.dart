import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_metric_tile.dart';

/// بلاطة العملاء، أو ما يقوم مقامها حين لا يُسمح بقراءتهم.
///
/// عدّاد كل المسجَّلين يصل لمن يقرأ كل الفروع فقط؛ وسواه يرى العمل المفتوح
/// أمامه بدل خانة «—»: صفرٌ في خانة حُجبت عنه كذب، وشرطةٌ تسأل لا تُجيب.
class DashboardCustomersTile extends StatelessWidget {
  const DashboardCustomersTile({super.key, required this.metrics});

  final AdminDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final total = metrics.totalCustomers;
    if (total == null) {
      return DashboardMetricTile(
        label: S.activeOrders,
        value: localizeDigits(formatCount(metrics.activeOrders)),
        icon: AppIcons.clock01,
        surface: AppColor.adminInfoSurface,
        ink: AppColor.adminInfo,
        current: 0,
        previous: 0,
        caption: S.dashboardOpenWorkCaption,
      );
    }
    final before = metrics.customersBeforeMonth;
    return DashboardMetricTile(
      label: S.customersLabel,
      value: localizeDigits(formatCount(total)),
      icon: AppIcons.userGroup,
      surface: AppColor.tintVioletSurface,
      ink: AppColor.tintVioletInk,
      current: total,
      previous: before ?? 0,
      caption: before == null
          ? S.dashboardAllCustomersCaption
          : S.dashboardBeforeThisMonth(localizeDigits(formatCount(before))),
    );
  }
}
