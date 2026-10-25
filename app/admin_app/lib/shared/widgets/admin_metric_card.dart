import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/app_color.dart';

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
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String? changeLabel;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 105),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: ShapeDecoration(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          shadows: dark
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x0A1B362B),
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
            const SizedBox(height: 7),
            Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: dark ? AppColor.darkText : AppColor.adminHeading,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
                fontSize: 9,
                fontWeight: FontWeight.w400,
                height: 1.5,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: positive
                    ? AppColor.trendPositiveSurface
                    : AppColor.trendNegativeSurface,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label!,
                      style: TextStyle(
                        color: trendColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(width: 3),
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
            )
          else
            const SizedBox.shrink(),
          Container(
            width: 33,
            height: 33,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
        ],
      ),
    );
  }
}
