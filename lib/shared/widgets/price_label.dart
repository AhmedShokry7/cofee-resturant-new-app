import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/currency_icon.dart';

/// Amount plus the standard [CurrencyIcon], replacing the old `25.00 SAR`
/// text suffix wherever a price is displayed visually.
///
/// The icon sits on the text baseline row with a small gap, sized per
/// context (card, details, totals, compact rows). [iconColor] defaults to
/// the text [style]'s color so symbol and amount always match; [iconSize]
/// defaults to the text size. Amounts never change here: formatting,
/// rounding and codes stay in [Formatters].
class PriceLabel extends StatelessWidget {
  const PriceLabel({
    super.key,
    required this.amount,
    this.prefix = '',
    this.style,
    this.iconSize,
    this.iconColor,
    this.gap = 4,
    this.mainAxisSize = MainAxisSize.min,
  });

  final double amount;

  /// Literal prepended to the amount (`-` for discounts, `+` for deltas).
  final String prefix;
  final TextStyle? style;
  final double? iconSize;
  final Color? iconColor;

  /// Gap between amount and icon in design pixels.
  final double gap;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final textStyle = style;
    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            '$prefix${Formatters.amount(amount)}',
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: gap.w),
        CurrencyIcon(
          size: iconSize ?? textStyle?.fontSize ?? 14,
          color: iconColor ?? textStyle?.color,
        ),
      ],
    );
  }
}
