import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Label on the left, value on the right — the standard breakdown row
/// (Sub-Total / Delivery / Discount / Total / order details).
class LabeledValueRow extends StatelessWidget {
  const LabeledValueRow({
    super.key,
    required this.label,
    this.value = '',
    this.emphasized = false,
    this.big = false,
    this.valueSize = 14,
    this.labelExpanded = false,
    this.priceValue,
    this.pricePrefix = '',
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

  /// Monetary value rendered with the standard currency icon instead of the
  /// `value` text (which is then ignored). Uses the same value style.
  final double? priceValue;

  /// Literal prepended to [priceValue] (`-` for discounts).
  final String pricePrefix;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppFonts.regular14(context)
        .copyWith(color: AppColor.greyColor);

    final valueStyle =
        (big
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
    final price = priceValue;
    final valueWidget = price == null
        ? Text(value, style: valueStyle)
        : PriceLabel(
            amount: price,
            prefix: pricePrefix,
            style: valueStyle,
            iconSize: valueStyle.fontSize,
            iconColor: valueStyle.color,
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (labelExpanded) ...[
          Expanded(child: labelWidget),
          SizedBox(width: AppSpacing.sm),
        ] else
          labelWidget,
        valueWidget,
      ],
    );
  }
}
