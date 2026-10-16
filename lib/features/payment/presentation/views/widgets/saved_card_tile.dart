import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';

class SavedCardTile extends StatelessWidget {
  const SavedCardTile({super.key, required this.card, required this.onDelete});

  final SavedCardModel card;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Row(
        children: [
          Container(
            height: 44.w,
            width: 44.w,
            decoration: BoxDecoration(
              color: AppColor.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              HugeIcons.strokeRoundedCreditCard,
              color: AppColor.primaryColor,
              size: 22.w,
            ),
          ),
          SizedBox(width: SpacingTokens.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.brand.label.isEmpty
                      ? S.cardBrandFallback
                      : card.brand.label,
                  style: AppFonts.semiBold16(context),
                ),
                SizedBox(height: 4.h),
                Text(
                  "**** **** **** ${card.last4}",
                  style: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                ),
              ],
            ),
          ),
          SizedBox(width: SpacingTokens.sm.w),
          Text(card.expiry, style: AppFonts.medium14(context)),
          SizedBox(width: SpacingTokens.md.w),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              HugeIcons.strokeRoundedDelete02,
              size: 22.w,
              color: AppColor.greyColor,
            ),
          ),
        ],
      ),
    );
  }
}
