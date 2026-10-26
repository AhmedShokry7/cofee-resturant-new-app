import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// A compact statistic tile used inside admin detail surfaces.
class AdminStatTile extends StatelessWidget {
  const AdminStatTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.surface,
    required this.label,
    this.value,
    this.money,
    this.moneyFormatter,
    this.valueColor,
  }) : assert(value != null || money != null);

  final IconData icon;
  final Color tint;
  final Color surface;
  final String label;
  final String? value;
  final double? money;
  final String Function(double value)? moneyFormatter;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final heading = dark ? AppColor.darkText : AppColor.adminHeading;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
        ),
        boxShadow: dark
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
          AdminIconTile(icon: icon, tint: tint, surface: surface),
          const SizedBox(height: AppSpacing.sm),
          if (money != null)
            AdminMoneyText(
              value: money!,
              fontSize: AppFontSizes.size15,
              color: valueColor ?? heading,
              formatter: moneyFormatter,
            )
          else
            Text(
              value!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? heading,
                fontSize: AppFontSizes.size15,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_4,
              ),
            ),
          const SizedBox(height: AppSizes.px2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: muted,
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_4,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminIconTile extends StatelessWidget {
  const AdminIconTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.surface,
    this.size = 26,
  });

  final IconData icon;
  final Color tint;
  final Color surface;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? tint.withValues(alpha: .16) : surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Center(
        child: AppIcon(
          icon,
          size: size * .58,
          color: dark ? Color.lerp(tint, AppColor.whiteColor, .35)! : tint,
        ),
      ),
    );
  }
}

class AdminMoneyText extends StatelessWidget {
  const AdminMoneyText({
    super.key,
    required this.value,
    this.fontSize = 15,
    this.color,
    this.formatter,
  });

  final double value;
  final double fontSize;
  final Color? color;
  final String Function(double value)? formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final resolved =
        color ?? (dark ? AppColor.darkText : AppColor.adminHeading);
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            formatter?.call(value) ?? localizeDigits(formatAmount(value)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: resolved,
              fontSize: fontSize,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_4,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        CurrencyIcon(size: fontSize - 1, color: muted),
      ],
    );
  }
}
