import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/kitchen/data/models/admin_kitchen_metrics.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class KitchenMetricsCards extends StatelessWidget {
  const KitchenMetricsCards({super.key, required this.metrics});

  final AdminKitchenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final queuedHint = metrics.queued > 0 && metrics.oldestWaitMinutes > 0
        ? localizeDigits(S.kitchenOldestWait(metrics.oldestWaitMinutes))
        : S.kitchenMetricQueuedHint;
    final preparingHint = metrics.avgPrepMinutes > 0
        ? localizeDigits(S.kitchenAveragePrep(metrics.avgPrepMinutes.round()))
        : S.kitchenMetricPreparingHint;
    final cards = <_KitchenMetric>[
      _KitchenMetric(
        label: S.kitchenMetricQueued,
        caption: queuedHint,
        value: localizeDigits('${metrics.queued}'),
        icon: HugeIcons.strokeRoundedChefHat,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
      ),
      _KitchenMetric(
        label: S.kitchenMetricPreparing,
        caption: preparingHint,
        value: localizeDigits('${metrics.preparing}'),
        icon: HugeIcons.strokeRoundedKitchenUtensils,
        iconBackground: AppColor.adminInfoSurface,
        iconColor: AppColor.adminInfo,
      ),
      _KitchenMetric(
        label: S.kitchenMetricReady,
        caption: S.kitchenMetricReadyHint,
        value: localizeDigits('${metrics.ready}'),
        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
        iconBackground: AppColor.trendPositiveSurface,
        iconColor: AppColor.trendPositive,
      ),
      _KitchenMetric(
        label: S.kitchenMetricLate,
        caption: localizeDigits(S.kitchenMetricLateHint),
        value: localizeDigits('${metrics.late}'),
        icon: HugeIcons.strokeRoundedAlarmClock,
        iconBackground: AppColor.trendNegativeSurface,
        iconColor: AppColor.trendNegative,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 760 ? 2 : 4;
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

class _KitchenMetric {
  const _KitchenMetric({
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
