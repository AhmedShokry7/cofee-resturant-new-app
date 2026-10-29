import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// مال المنتج وحصّته من إيراد الأسبوع، في زاوية الصف.
///
/// المال وحده لا يكفي: «٤٨٠ ر.س» لا يقول كم ذلك من المتجر. والنسبة من Domain
/// لا من هنا، لأن قسمة إيراد المنتج على إيراد الأسبوع قرار جمع، والعرض لا يجمع.
class DashboardTopProductFigure extends StatelessWidget {
  const DashboardTopProductFigure({
    super.key,
    required this.revenue,
    required this.share,
  });

  final double revenue;

  /// حصة المنتج من إيراد الأسبوع، بين ٠ و١.
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                localizeDigits(formatAmount(revenue)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminAmountColor(theme),
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.px4),
            CurrencyIcon(size: 13, color: adminAmountColor(theme)),
          ],
        ),
        const SizedBox(width: AppSizes.px10),
        Text(
          formatPercent(share * 100),
          style: const TextStyle(
            color: AppColor.tintGreenInk,
            fontSize: AppFontSizes.size9,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_5,
          ),
        ),
      ],
    );
  }
}
