import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

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
    this.isMoney = false,
    this.captionIsMoney = false,
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

  /// Put the riyal mark next to [value]: a money card prints its number alone
  /// and the currency rides as an icon, like every other price in the app.
  final bool isMoney;

  /// Same mark for [caption], whose amount is the last thing on the line.
  final bool captionIsMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final grey = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 12,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس البطاقة: فقاعة الأيقونة عند البداية، وشارة الاتجاه عند النهاية
          // — بحيز مرن حتى لا تُجزع البطاقة على العرض الضيق.
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const Spacer(),
              if (changeLabel != null)
                Flexible(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _TrendChip(
                      label: changeLabel!,
                      positive: isPositive,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.px10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: grey,
              fontSize: AppFontSizes.size10,
              fontWeight: AppFontWeights.medium,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSizes.px2),
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: dark ? AppColor.darkText : AppColor.adminHeading,
                    fontSize: AppFontSizes.size22,
                    fontWeight: AppFontWeights.bold,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (isMoney) ...[
                const SizedBox(width: AppSizes.px4),
                CurrencyIcon(
                  size: AppFontSizes.size22 - 3,
                  color: dark
                      ? AppColor.darkTextSecondary
                      : AppColor.adminMuted,
                ),
              ],
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSizes.px4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: grey,
                      fontSize: AppFontSizes.size8_5,
                      height: 1.4,
                    ),
                  ),
                ),
                if (captionIsMoney) ...[
                  const SizedBox(width: AppSizes.px4),
                  CurrencyIcon(size: 10, color: grey),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// شارة الاتجاه: سهم يقرأه العين قبل الرقم، والنسبة تُقرأ بعده.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final trendColor = positive
        ? AppColor.trendPositive
        : AppColor.trendNegative;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: positive
              ? AppColor.trendPositiveSurface
              : AppColor.trendNegativeSurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              positive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 13,
              color: trendColor,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: trendColor,
                  fontSize: AppFontSizes.size9,
                  fontWeight: AppFontWeights.bold,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
