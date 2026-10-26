import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/tables/domain/entities/dining_overview.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class DiningMetricsCards extends StatelessWidget {
  const DiningMetricsCards({super.key, required this.metrics});

  final DiningMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      AdminMetricCard(
        label: S.tablesMetricTotal,
        value: localizeDigits('${metrics.tables}'),
        icon: AppIcons.table01,
        iconBackground: AppColor.adminAccentSurface,
        iconColor: AppColor.adminAccent,
        caption: S.tablesMetricTotalHint,
      ),
      AdminMetricCard(
        label: S.tablesMetricAvailable,
        value: localizeDigits('${metrics.available}'),
        icon: AppIcons.checkmarkCircle02,
        iconBackground: AppColor.trendPositiveSurface,
        iconColor: AppColor.trendPositive,
        caption: S.tablesMetricAvailableHint,
      ),
      AdminMetricCard(
        label: S.tablesMetricOccupied,
        value: localizeDigits('${metrics.occupied}'),
        icon: AppIcons.restaurant01,
        iconBackground: AppColor.errorColor.withValues(alpha: .12),
        iconColor: AppColor.errorColor,
        caption: S.tablesMetricOccupiedHint,
      ),
      AdminMetricCard(
        label: S.tablesMetricReserved,
        value: localizeDigits('${metrics.reserved}'),
        icon: AppIcons.calendar01,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
        caption: S.tablesMetricReservedHint,
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
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}
