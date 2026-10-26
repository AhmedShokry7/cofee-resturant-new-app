import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class CouponMetricsCards extends StatelessWidget {
  const CouponMetricsCards({super.key, required this.metrics});

  final AdminCouponMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData(
        label: S.couponsMetricActive,
        caption: S.couponsMetricActiveHint,
        value: couponCount(metrics.active),
        icon: AppIcons.ticket01,
        iconBackground: AppColor.adminAccentSurface,
        iconColor: AppColor.adminAccent,
      ),
      _MetricData(
        label: S.couponsMetricExpiring,
        caption: S.couponsMetricExpiringHint,
        value: couponCount(metrics.expiringSoon),
        icon: AppIcons.clock01,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
      ),
      _MetricData(
        label: S.couponsMetricRedemptions,
        caption: S.couponsMetricRedemptionsHint,
        value: couponCount(metrics.redemptions),
        icon: AppIcons.chartLineData01,
        iconBackground: AppColor.adminInfoSurface,
        iconColor: AppColor.adminInfo,
      ),
      _MetricData(
        label: S.couponsMetricDiscountGiven,
        caption: S.couponsMetricDiscountGivenHint,
        value: couponMoneyWithCurrency(metrics.discountGiven),
        icon: AppIcons.coins01,
        iconBackground: AppColor.adminAccentSurface,
        iconColor: AppColor.trendPositive,
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
