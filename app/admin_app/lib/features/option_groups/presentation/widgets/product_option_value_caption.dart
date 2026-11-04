import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// اسم الخيار وزيادة مجموعته تحته، في طرف السطر قبل حقل السعر.
///
/// زيادة المجموعة تُعرض دائمًا ولو كان للمشروب سعر خاص: من يقرأ الرقمين معًا
/// يعرف هل هو الذي غيّر السعر أم المجموعة.
class ProductOptionValueCaption extends StatelessWidget {
  const ProductOptionValueCaption({super.key, required this.value});

  final AdminProductOptionValue value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.nameFor(AppLocale.instance.language),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: adminBodyColor(theme),
            fontSize: AppFontSizes.size11,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_5,
          ),
        ),
        const SizedBox(height: AppSizes.px2),
        Row(
          children: [
            Text(
              '${S.groupDeltaLabel}: ${localizeDigits(formatDelta(value.groupDelta))}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9_5,
              ),
            ),
            const SizedBox(width: AppSizes.px2),
            const CurrencyIcon(size: AppSizes.px10),
          ],
        ),
      ],
    );
  }
}
