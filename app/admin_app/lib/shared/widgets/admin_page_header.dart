import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';

/// The title, subtitle and actions of an admin page.
///
/// It matches the customers and orders headers and stacks the actions under
/// the title on narrow screens so long Arabic labels never overflow.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const <Widget>[],
    this.progress,
    this.progressLabel,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final double? progress;
  final String? progressLabel;

  /// Content under the title, such as the bulk selection row of products.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null) ...[
          _ProgressRow(progress: progress!, label: progressLabel, dark: dark),
          const SizedBox(height: AppSpacing.sm),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: dark ? AppColor.darkText : AppColor.adminHeading,
                    fontSize: AppFontSizes.size23,
                    fontWeight: AppFontWeights.bold,
                    height: 1.5,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: AppFontSizes.size12_5,
                    height: 1.5,
                  ),
                ),
              ],
            );

            if (actions.isEmpty) return heading;

            final actionRow = Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            );

            if (constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: actionRow,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: heading),
                actionRow,
              ],
            );
          },
        ),
        if (footer != null) ...[const SizedBox(height: AppSpacing.sm), footer!],
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.progress, required this.dark, this.label});

  final double progress;
  final bool dark;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = dark ? AppColor.darkTextSecondary : AppColor.greyColor;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: dark
                ? AppColor.darkSurfaceContainer
                : AppColor.lightGreyColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              dark ? AppColor.secondaryColor : AppColor.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          localizeDigits('${(progress * 100).toInt()}%'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: muted,
            fontWeight: AppFontWeights.semiBold,
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ],
    );
  }
}
