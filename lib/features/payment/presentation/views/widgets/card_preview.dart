import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/data/model/card_brand.dart';

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
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColor.primaryColor, AppColor.secondryColor],
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  HugeIcons.strokeRoundedCreditCard,
                  color: AppColor.whiteColor,
                  size: 28.w,
                ),
                if (brand != CardBrand.unknown)
                  Text(
                    brand.label,
                    style: AppFonts.bold16(context)
                        .copyWith(color: AppColor.whiteColor, letterSpacing: 1),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              number.isEmpty ? "#### #### #### ####" : number,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.semiBold18(context)
                  .copyWith(color: AppColor.whiteColor, letterSpacing: 2),
            ),
            SizedBox(height: SpacingTokens.md.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _CardField(
                    label: S.cardHolder,
                    value: name.isEmpty ? S.yourName : name.toUpperCase(),
                  ),
                ),
                SizedBox(width: SpacingTokens.md.w),
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
        SizedBox(height: 2.h),
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
