import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class ReviewMetricsCards extends StatelessWidget {
  const ReviewMetricsCards({super.key, required this.metrics});

  final AdminReviewMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData(
        label: S.reviewsMetricAverage,
        caption: localizeDigits(S.reviewsBasedOn(metrics.total)),
        value: metrics.total == 0
            ? '—'
            : reviewAverageValue(metrics.averageRating),
        icon: HugeIcons.strokeRoundedStar,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
      ),
      _MetricData(
        label: S.reviewsMetricTotal,
        caption: localizeDigits(
          S.reviewsMetricTotalHint(metrics.published, metrics.hidden),
        ),
        value: reviewCountValue(metrics.total),
        icon: HugeIcons.strokeRoundedComment01,
        iconBackground: AppColor.adminAccentSurface,
        iconColor: AppColor.adminAccent,
      ),
      _MetricData(
        label: S.reviewsMetricLow,
        caption: S.reviewsMetricLowHint,
        value: reviewCountValue(metrics.lowRatings),
        icon: HugeIcons.strokeRoundedAlertCircle,
        iconBackground: AppColor.trendNegativeSurface,
        iconColor: AppColor.trendNegative,
      ),
      _MetricData(
        label: S.reviewsMetricHidden,
        caption: S.reviewsMetricHiddenHint,
        value: reviewCountValue(metrics.hidden),
        icon: HugeIcons.strokeRoundedViewOff,
        iconBackground: AppColor.adminTableHeader,
        iconColor: AppColor.adminMuted,
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
