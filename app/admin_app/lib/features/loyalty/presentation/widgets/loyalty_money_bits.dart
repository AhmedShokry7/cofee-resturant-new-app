import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// A loyalty line whose amount wears the riyal mark, e.g. `لاتيه • ١٥٫٠٠ ￼`.
class LoyaltyMoneyText extends StatelessWidget {
  const LoyaltyMoneyText({
    super.key,
    required this.sentence,
    required this.style,
  });

  final LoyaltyMoneySentence sentence;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (!sentence.hasMoney) {
      return Text(
        sentence.before,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final iconSize = ((style.fontSize ?? AppFontSizes.size12) + 2).clamp(
      10.0,
      20.0,
    );
    final mark = CurrencyIcon(size: iconSize, color: style.color);
    return Row(
      children: [
        if (sentence.before.isNotEmpty) ...[
          Flexible(
            child: Text(
              sentence.before,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: AppSizes.px6),
        ],
        Flexible(
          child: Text(
            sentence.amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: AppSizes.px4),
        mark,
        if (sentence.after.isNotEmpty) ...[
          const SizedBox(width: AppSizes.px4),
          Flexible(
            child: Text(
              sentence.after,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ],
    );
  }
}
