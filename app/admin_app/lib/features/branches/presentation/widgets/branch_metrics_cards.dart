import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/branches/data/models/admin_branch_metrics.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class BranchMetricsCards extends StatelessWidget {
  const BranchMetricsCards({super.key, required this.metrics});

  final AdminBranchMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      AdminMetricCard(
        label: S.branchesMetricTotal,
        value: localizeDigits('${metrics.total}'),
        icon: HugeIcons.strokeRoundedStore01,
        iconBackground: AppColor.adminAccentSurface,
        iconColor: AppColor.adminAccent,
        caption: localizeDigits(
          S.branchesMetricActiveCaption(metrics.active, metrics.total),
        ),
      ),
      AdminMetricCard(
        label: S.branchesMetricActive,
        value: localizeDigits('${metrics.active}'),
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        iconBackground: AppColor.trendPositiveSurface,
        iconColor: AppColor.trendPositive,
        caption: localizeDigits(
          S.branchesMetricStaffCaption(metrics.staffAssigned),
        ),
      ),
      AdminMetricCard(
        label: S.branchesMetricOrders,
        value: localizeDigits('${metrics.orders30d}'),
        icon: HugeIcons.strokeRoundedShoppingBag01,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
        caption: S.branchesMetricOrdersCaption,
      ),
      AdminMetricCard(
        label: S.branchesMetricZones,
        value: localizeDigits('${metrics.zonesCovered}'),
        icon: HugeIcons.strokeRoundedDeliveryTruck01,
        iconBackground: AppColor.adminInfoSurface,
        iconColor: AppColor.adminInfo,
        caption: S.branchesMetricZonesCaption,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 900 ? 2 : 4;
        const spacing = 13.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}
