import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_overview.dart';
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
        icon: AppIcons.userMultiple,
        iconBackground: AppColor.adminInfoSurface,
        iconColor: AppColor.adminInfo,
      ),
      _MetricData(
        label: S.loyaltyMetricPointsOutstanding,
        value: loyaltyCount(overview.pointsOutstanding),
        icon: AppIcons.star,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
      ),
      _MetricData(
        label: S.loyaltyMetricRedemptions,
        value: loyaltyCount(overview.redemptions),
        icon: AppIcons.gift,
        iconBackground: AppColor.tintGreenSurface,
        iconColor: AppColor.trendPositive,
      ),
      _MetricData(
        label: S.loyaltyMetricActiveRewards,
        value: loyaltyCount(overview.activeRewards),
        icon: AppIcons.checkmarkBadge01,
        iconBackground: AppColor.tintVioletSurface,
        iconColor: AppColor.tintVioletInk,
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
