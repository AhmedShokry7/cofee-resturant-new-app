import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_metrics.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class AuditMetricsCards extends StatelessWidget {
  const AuditMetricsCards({super.key, required this.metrics});

  final AdminAuditMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final latest = metrics.latestAt == null
        ? S.auditMetricNoActivity
        : auditRelativeTimeLabel(metrics.latestAt);
    final cards = <_MetricData>[
      _MetricData(
        label: S.auditMetricTotal,
        caption: localizeDigits(S.auditMetricTotalHint(metrics.week)),
        value: localizeDigits('${metrics.total}'),
        icon: HugeIcons.strokeRoundedClipboard,
        iconBackground: AppColor.adminAccentSurface,
        iconColor: AppColor.adminAccent,
      ),
      _MetricData(
        label: S.auditMetricToday,
        caption: localizeDigits(S.auditMetricTodayHint(latest)),
        value: localizeDigits('${metrics.today}'),
        icon: HugeIcons.strokeRoundedCalendar03,
        iconBackground: AppColor.adminInfoSurface,
        iconColor: AppColor.adminInfo,
      ),
      _MetricData(
        label: S.auditMetricCritical,
        caption: localizeDigits(
          S.auditMetricCriticalWeekHint(metrics.criticalWeek),
        ),
        value: localizeDigits('${metrics.critical}'),
        icon: HugeIcons.strokeRoundedShield01,
        iconBackground: AppColor.trendNegativeSurface,
        iconColor: AppColor.trendNegative,
      ),
      _MetricData(
        label: S.auditMetricActors,
        caption: localizeDigits(S.auditMetricActorsHint(metrics.branches)),
        value: localizeDigits('${metrics.actors}'),
        icon: HugeIcons.strokeRoundedUserMultiple,
        iconBackground: AppColor.trendPositiveSurface,
        iconColor: AppColor.trendPositive,
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
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: AdminMetricCard(
                  label: card.label,
                  caption: card.caption,
                  value: card.value,
                  icon: card.icon,
                  iconBackground: card.iconBackground,
                  iconColor: card.iconColor,
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
    required this.caption,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  final String label;
  final String caption;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
}
