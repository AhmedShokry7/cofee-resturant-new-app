import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';

/// A small percentage pill, e.g. `20%`.
///
/// The dashboard has no picture badge, so the discount is stated in words and
/// in a number: the pill carries the percentage and the line next to it
/// carries the price the customer will pay.
class DiscountPill extends StatelessWidget {
  const DiscountPill({super.key, required this.percent, this.muted = false});

  /// The discount in percent.
  final int percent;

  /// A muted pill is used for a discount that is not running right now.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: muted ? AppColor.greyColor : AppColor.primaryColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$percent%',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColor.whiteColor,
          fontSize: AppFontSizes.size11,
          fontWeight: AppFontWeights.semiBold,
        ),
      ),
    );
  }
}
