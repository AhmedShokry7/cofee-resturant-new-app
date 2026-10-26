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

/// A bordered admin surface with a heading, an optional count and trailing
/// action, shared by the detail pages.
class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.count,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final String title;
  final Widget child;
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
              Expanded(
                child: Text(
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
