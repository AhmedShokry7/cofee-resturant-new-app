import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';

bool adminIsDark(ThemeData theme) => theme.brightness == Brightness.dark;

Color adminHeadingColor(ThemeData theme) =>
    adminIsDark(theme) ? AppColor.darkText : AppColor.adminHeading;

Color adminBodyColor(ThemeData theme) =>
    adminIsDark(theme) ? AppColor.darkText : AppColor.adminBody;

/// لون المبلغ المطبوع في جدول أو بطاقة: أثقل من النص وأخف من العنوان.
Color adminAmountColor(ThemeData theme) =>
    adminIsDark(theme) ? AppColor.darkText : AppColor.adminAmount;

/// لون التاريخ في الأسطر: أهدأ من النص لأنه يُقارَن ولا يُقرأ وحده.
Color adminDateColor(ThemeData theme) =>
    adminIsDark(theme) ? AppColor.darkTextSecondary : AppColor.adminDate;

Color adminMutedColor(ThemeData theme) =>
    adminIsDark(theme) ? AppColor.darkTextSecondary : AppColor.adminMuted;

Color adminSubtleColor(ThemeData theme) =>
    adminIsDark(theme) ? AppColor.darkTextSecondary : AppColor.adminSubtle;

Color adminCardBorderColor(ThemeData theme) =>
    adminIsDark(theme) ? AppColor.darkBorder : AppColor.adminCardBorder;

Color adminControlBorderColor(ThemeData theme) =>
    adminIsDark(theme) ? AppColor.darkBorder : AppColor.adminControlBorder;

Color adminRowBorderColor(ThemeData theme) =>
    adminIsDark(theme) ? AppColor.darkBorder : AppColor.adminRowBorder;

Color adminTintedSurfaceColor(ThemeData theme) => adminIsDark(theme)
    ? AppColor.darkSurfaceContainer
    : AppColor.adminTableHeader;

Color adminFlagForeground(ThemeData theme, Color color) =>
    adminIsDark(theme) ? Color.lerp(color, AppColor.whiteColor, .35)! : color;

Color adminFlagBackground(ThemeData theme, Color color, Color lightSurface) =>
    adminIsDark(theme) ? color.withValues(alpha: .16) : lightSurface;

/// A bordered admin surface with a heading, an optional subtitle and count and
/// a trailing action, shared by the detail pages.
///
/// The subtitle is part of the card, not a line the page adds under the title:
/// a card that explains itself in two lines does it the same way on every page.
class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.count,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// علامة البطاقة قبل عنوانها: أيقونة القسم أو شارة عدّها، فلا تُركّب كل صفحة
  /// رأسًا خاصًا بها حين تختلف العلامة فقط.
  final Widget? leading;
  final int? count;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminHeadingColor(theme),
                        fontSize: AppFontSizes.size13,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size10,
                          fontWeight: AppFontWeights.regular,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                  ],
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: adminFlagBackground(
                      theme,
                      AppColor.adminAccent,
                      AppColor.adminAccentSurface,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    localizeDigits('$count'),
                    style: TextStyle(
                      color: adminFlagForeground(theme, AppColor.adminAccent),
                      fontSize: AppFontSizes.size9,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
