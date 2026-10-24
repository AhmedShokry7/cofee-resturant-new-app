import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? AppColor.greyColor : AppColor.primaryColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        '$percent%',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColor.whiteColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
