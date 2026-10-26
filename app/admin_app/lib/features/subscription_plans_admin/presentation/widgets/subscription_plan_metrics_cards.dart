import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/subscription_plans_admin/data/models/admin_subscription_plan_metrics.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class SubscriptionPlanMetricsCards extends StatelessWidget {
  const SubscriptionPlanMetricsCards({super.key, required this.metrics});

  final AdminSubscriptionPlanMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData(
        label: S.subscriptionPlansTotalMetric,
        value: localizeDigits('${metrics.total}'),
        icon: HugeIcons.strokeRoundedPackage,
        iconBackground: const Color(0xFFE9EDF8),
        iconColor: const Color(0xFF5F70A8),
      ),
      _MetricData(
        label: S.subscriptionPlansOnSaleMetric,
        value: localizeDigits('${metrics.onSale}'),
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        iconBackground: const Color(0xFFE8F3EC),
        iconColor: const Color(0xFF3D8A68),
      ),
      _MetricData(
        label: S.subscriptionPlansActiveSubscribersMetric,
        value: localizeDigits('${metrics.activeSubscribers}'),
        icon: HugeIcons.strokeRoundedUserMultiple,
        iconBackground: const Color(0xFFF0EAFB),
        iconColor: const Color(0xFF7E57C2),
      ),
      _MetricData(
        label: S.subscriptionPlansAutoRenewMetric,
        value: localizeDigits('${metrics.autoRenewPlans}'),
        icon: HugeIcons.strokeRoundedRefresh,
        iconBackground: const Color(0xFFFBF2DC),
        iconColor: const Color(0xFFA47B2F),
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
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
}
