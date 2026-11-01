import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/data/model/card_brand.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class CardPreview extends StatelessWidget {
  const CardPreview({
    super.key,
    required this.number,
    required this.name,
    required this.expiry,
  });

  final String number;
  final String name;
  final String expiry;

  @override
  Widget build(BuildContext context) {
    final brand = detectCardBrand(number);
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColor.primaryColor, AppColor.secondryColor],
          ),
          borderRadius: BorderRadius.circular(AppRadius.r16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  AppIcons.creditCard,
                  color: AppColor.whiteColor,
                  size: AppSizes.px28,
                ),
                if (brand != CardBrand.unknown)
                  Text(
                    brand.label,
                    style: AppFonts.bold16(context).copyWith(
                      color: AppColor.whiteColor,
                      letterSpacing: AppLetterSpacings.brand,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              number.isEmpty ? "#### #### #### ####" : number,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.semiBold18(context).copyWith(
                color: AppColor.whiteColor,
                letterSpacing: AppLetterSpacings.number,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _CardField(
                    label: S.cardHolder,
                    value: name.isEmpty ? S.yourName : name.toUpperCase(),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                _CardField(
                  label: S.expires,
                  value: expiry.isEmpty ? "MM/YY" : expiry,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardField extends StatelessWidget {
  const _CardField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.regular12(context)
              .copyWith(color: AppColor.whiteColor.withValues(alpha: 0.7)),
        ),
        SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.medium14(context)
              .copyWith(color: AppColor.whiteColor),
        ),
      ],
    );
  }
}
