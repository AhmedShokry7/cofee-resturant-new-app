import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';

/// نسبة التغيير بين رقم ونقطة مقارنته، كما تُطبع على شارة البطاقة.
class AdminMetricTrend {
  const AdminMetricTrend({required this.label, required this.positive});

  final String label;
  final bool positive;
}

/// التغيّر النسبي بين رقم وقيمته السابقة.
///
/// `null` حين لا نقطة مقارنة بعد: بطاقة تقول «+٠٪» مقابل صفر هي كذبة، فالشارة
/// تُخفى أصلًا. والإشارة مطبوعة مع النسبة لا مع السهم وحده: قارئ الشاشة يلفظ
/// النصّ وحده، فـ«١٠٠٪» بلا «−» تُسمع ارتفاعًا وهي انحدار كامل.
AdminMetricTrend? metricPercentTrend(num current, num previous) {
  if (previous <= 0) return null;
  final change = (current - previous) / previous * 100;
  final positive = change >= 0;
  return AdminMetricTrend(
    label: '${positive ? '+' : '−'}${formatPercent(change.abs())}',
    positive: positive,
  );
}

/// One statistic card of an admin page: a trend badge, an icon and a value.
class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    this.changeLabel,
    this.isPositive = true,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String? changeLabel;
  final bool isPositive;

  /// A quiet second line that explains what the number counts.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 105),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: ShapeDecoration(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          shadows: dark
              ? const []
              : const [
                  BoxShadow(
                    color: AppColor.inkWashFaint,
                    blurRadius: 24,
                    offset: Offset(0, 5),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MetricBadge(
              label: changeLabel,
              positive: isPositive,
              icon: icon,
              iconColor: iconColor,
              iconBackground: iconBackground,
            ),
            const SizedBox(height: AppSizes.px8),
            Text(
              value,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: dark ? AppColor.darkText : AppColor.adminHeading,
                fontSize: AppFontSizes.size21,
                fontWeight: AppFontWeights.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSizes.px1),
            Text(
              label,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
                fontSize: AppFontSizes.size9,
                fontWeight: AppFontWeights.regular,
                height: 1.5,
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                textAlign: TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      (dark ? AppColor.darkTextSecondary : AppColor.adminMuted)
                          .withValues(alpha: .8),
                  fontSize: AppFontSizes.size8_5,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.label,
    required this.positive,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final String? label;
  final bool positive;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    final trendColor = positive
        ? AppColor.trendPositive
        : AppColor.trendNegative;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (label != null)
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: positive
                      ? AppColor.trendPositiveSurface
                      : AppColor.trendNegativeSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: trendColor,
                            fontSize: AppFontSizes.size8,
                            fontWeight: AppFontWeights.semiBold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.px4),
                      Icon(
                        positive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: trendColor,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          const SizedBox(width: AppSizes.px6),
          Container(
            width: 33,
            height: 33,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
        ],
      ),
    );
  }
}
