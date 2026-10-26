import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_overview.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class LoyaltyMetricsCards extends StatelessWidget {
  const LoyaltyMetricsCards({super.key, required this.overview});

  final AdminLoyaltyOverview overview;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData(
        label: S.loyaltyMetricMembers,
        value: loyaltyCount(overview.members),
        icon: HugeIcons.strokeRoundedUserMultiple,
        iconBackground: const Color(0xFFE9EDF8),
        iconColor: const Color(0xFF5F70A8),
      ),
      _MetricData(
        label: S.loyaltyMetricPointsOutstanding,
        value: loyaltyCount(overview.pointsOutstanding),
        icon: HugeIcons.strokeRoundedStar,
        iconBackground: const Color(0xFFFBF2DC),
        iconColor: const Color(0xFFA47B2F),
      ),
      _MetricData(
        label: S.loyaltyMetricRedemptions,
        value: loyaltyCount(overview.redemptions),
        icon: HugeIcons.strokeRoundedGift,
        iconBackground: const Color(0xFFE8F3EC),
        iconColor: const Color(0xFF3D8A68),
      ),
      _MetricData(
        label: S.loyaltyMetricActiveRewards,
        value: loyaltyCount(overview.activeRewards),
        icon: HugeIcons.strokeRoundedCheckmarkBadge01,
        iconBackground: const Color(0xFFF0EAFB),
        iconColor: const Color(0xFF7E57C2),
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
