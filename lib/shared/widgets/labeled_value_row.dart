import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

/// Label on the left, value on the right — the standard breakdown row
/// (Sub-Total / Delivery / Discount / Total / order details).
class LabeledValueRow extends StatelessWidget {
  const LabeledValueRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.big = false,
    this.valueSize = 14,
    this.labelExpanded = false,
  });

  final String label;
  final String value;

  /// Value turns primary-colored and semi-bold (totals, discounts).
  final bool emphasized;

  /// Value uses the largest size (grand total).
  final bool big;

  /// Value font size (14 default, 16 for order detail rows).
  final double valueSize;

  /// Lets the label take remaining space (dense detail lists).
  final bool labelExpanded;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppFonts.regular14(
      context,
    ).copyWith(color: AppColor.greyColor);

    final valueStyle = (big
            ? AppFonts.semiBold18(context)
            : emphasized
                ? AppFonts.semiBold16(context)
                : valueSize == 16
                    ? AppFonts.semiBold16(context)
                    : AppFonts.semiBold14(context))
        .copyWith(
          color: emphasized ? AppColor.primaryColor : AppColor.blackColor,
        );

    final labelWidget = Text(label, style: labelStyle);
    final valueWidget = Text(value, style: valueStyle);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (labelExpanded) ...[
          Expanded(child: labelWidget),
          SizedBox(width: SpacingTokens.sm.w),
        ] else
          labelWidget,
        valueWidget,
      ],
    );
  }
}

