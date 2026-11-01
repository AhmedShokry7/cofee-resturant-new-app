import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/layout_tokens.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';

class SavedCardTile extends StatelessWidget {
  const SavedCardTile({
    super.key,
    required this.card,
    required this.onDelete,
    this.onSetDefault,
  });

  final SavedCardModel card;
  final VoidCallback onDelete;

  /// Makes this card the customer's preferred one. Omitted on the checkout
  /// picker, which shows the same rows without offering to change the default.
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: card.isDefault ? AppColor.primaryColor : AppColor.borderColor,
          width: card.isDefault ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 44.w,
            width: 44.w,
            decoration: BoxDecoration(
              color: AppColor.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(LayoutTokens.cardRadius.r),
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
                Row(
                  children: [
                    Text(
                      card.brand.label.isEmpty
                          ? S.cardBrandFallback
                          : card.brand.label,
                      style: AppFonts.semiBold16(context),
                    ),
                    if (card.isDefault) ...[
                      SizedBox(width: SpacingTokens.xs.w),
                      _DefaultBadge(),
                    ],
                  ],
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
          if (onSetDefault != null && !card.isDefault)
            GestureDetector(
              onTap: onSetDefault,
              child: Icon(
                HugeIcons.strokeRoundedStar,
                size: 20.w,
                color: AppColor.greyColor,
              ),
            )
          else
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

class _DefaultBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColor.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        S.defaultCardBadge,
        style: AppFonts.medium12(context).copyWith(
          color: AppColor.primaryColor,
        ),
      ),
    );
  }
}
