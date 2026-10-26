import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_stars.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// The average score and the 1..5 breakdown. Selecting a row filters the
/// directory by that star count; selecting it again clears the filter.
class ReviewRatingSummary extends StatelessWidget {
  const ReviewRatingSummary({
    super.key,
    required this.metrics,
    required this.selectedRating,
    required this.onRatingSelected,
  });

  final AdminReviewMetrics metrics;
  final int? selectedRating;
  final ValueChanged<int?> onRatingSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = _AverageBlock(metrics: metrics);
    final distribution = _DistributionBars(
      metrics: metrics,
      selectedRating: selectedRating,
      onRatingSelected: onRatingSelected,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: adminCardBorderColor(theme)),
        boxShadow: adminIsDark(theme)
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x0A1B362B),
                  blurRadius: 24,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                average,
                const SizedBox(height: 12),
                Divider(height: 1, color: adminRowBorderColor(theme)),
                const SizedBox(height: 12),
                distribution,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 258, child: average),
              Container(
                width: 1,
                height: 104,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: adminRowBorderColor(theme),
              ),
              Expanded(child: distribution),
            ],
          );
        },
      ),
    );
  }
}

class _AverageBlock extends StatelessWidget {
  const _AverageBlock({required this.metrics});

  final AdminReviewMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReviews = metrics.total > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          S.reviewsMetricAverage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size9,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_4,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              hasReviews ? reviewAverageValue(metrics.averageRating) : '—',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: adminHeadingColor(theme),
                fontSize: AppFontSizes.size31,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_1,
                letterSpacing: AppLetterSpacings.spaceNegative0_8,
              ),
            ),
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '/ 5',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: adminSubtleColor(theme),
                  fontSize: AppFontSizes.size10,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReviewStars(
                      rating: hasReviews ? metrics.averageRating : 0,
                      size: 14,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localizeDigits(S.reviewsBasedOn(metrics.total)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hasReviews) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              _SummaryChip(
                icon: HugeIcons.strokeRoundedThumbsUp,
                label: S.reviewsSatisfactionChip(
                  reviewPercentValue(metrics.satisfactionRate),
                ),
                color: AppColor.trendPositive,
              ),
              _SummaryChip(
                icon: HugeIcons.strokeRoundedCheckmarkBadge02,
                label: localizeDigits(S.reviewsVerifiedCount(metrics.verified)),
                color: AppColor.adminInfo,
              ),
              _SummaryChip(
                icon: HugeIcons.strokeRoundedCalendar03,
                label: localizeDigits(
                  S.reviewsThisMonthCount(metrics.thisMonth),
                ),
                color: AppColor.adminMuted,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = adminFlagForeground(theme, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          color,
          Color.lerp(color, AppColor.whiteColor, .88)!,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 11, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: foreground,
              fontSize: AppFontSizes.size8,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionBars extends StatelessWidget {
  const _DistributionBars({
    required this.metrics,
    required this.selectedRating,
    required this.onRatingSelected,
  });

  final AdminReviewMetrics metrics;
  final int? selectedRating;
  final ValueChanged<int?> onRatingSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.reviewsDistribution,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminBodyColor(theme),
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.bold,
                  height: AppTextHeights.line1_4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              S.reviewsDistributionHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminSubtleColor(theme),
                fontSize: AppFontSizes.size8,
                height: AppTextHeights.line1_4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var rating = 5; rating >= 1; rating--)
          _DistributionRow(
            rating: rating,
            count: metrics.countFor(rating),
            total: metrics.total,
            selected: selectedRating == rating,
            onTap: () =>
                onRatingSelected(selectedRating == rating ? null : rating),
          ),
      ],
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.rating,
    required this.count,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final int rating;
  final int count;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      selected: selected,
      child: Tooltip(
        message: S.reviewsFilterByStars(rating),
        child: Material(
          color: selected
              ? adminFlagBackground(
                  theme,
                  AppColor.adminAccent,
                  AppColor.adminAccentSurface,
                )
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 27,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            localizeDigits('$rating'),
                            style: TextStyle(
                              color: adminBodyColor(theme),
                              fontSize: AppFontSizes.size9_5,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_4,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: AppColor.adminWarning,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: adminTintedSurfaceColor(theme),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          selected
                              ? adminFlagForeground(theme, AppColor.adminAccent)
                              : AppColor.adminWarning.withValues(alpha: .8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text(
                      reviewCountValue(count),
                      textAlign: TextAlign.end,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: count > 0
                            ? adminBodyColor(theme)
                            : adminSubtleColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
