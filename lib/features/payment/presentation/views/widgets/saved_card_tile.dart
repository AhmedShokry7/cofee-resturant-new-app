import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(
          color: card.isDefault ? AppColor.primaryColor : AppColor.borderColor,
          width: card.isDefault ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: AppSizes.px44,
            width: AppSizes.px44,
            decoration: BoxDecoration(
              color: AppColor.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            ),
            child: Icon(
              AppIcons.creditCard,
              color: AppColor.primaryColor,
              size: AppSizes.px22,
            ),
          ),
          SizedBox(width: AppSpacing.md),
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
                      SizedBox(width: AppSpacing.xs),
                      _DefaultBadge(),
                    ],
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  "**** **** **** ${card.last4}",
                  style: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Text(card.expiry, style: AppFonts.medium14(context)),
          SizedBox(width: AppSpacing.md),
          if (onSetDefault != null && !card.isDefault)
            GestureDetector(
              onTap: onSetDefault,
              child: Icon(
                AppIcons.star,
                size: AppSizes.px20,
                color: AppColor.greyColor,
              ),
            )
          else
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                AppIcons.delete,
                size: AppSizes.px22,
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
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.px6,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColor.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.r20),
      ),
      child: Text(
        S.defaultCardBadge,
        style: AppFonts.medium12(context)
            .copyWith(color: AppColor.primaryColor),
      ),
    );
  }
}
