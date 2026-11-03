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
            _TrailingAction(
              icon: AppIcons.star,
              label: S.setDefaultCard,
              onTap: onSetDefault!,
            )
          else
            _TrailingAction(
              icon: AppIcons.delete,
              label: S.delete,
              onTap: onDelete,
            ),
        ],
      ),
    );
  }
}

/// The one icon at the end of a saved card: make it the default, or delete it.
///
/// Both actions are the same control with a different glyph, and a bare icon is
/// too small a target for a thumb, so the padding is part of the tappable box
/// rather than a gap next to it.
class _TrailingAction extends StatelessWidget {
  const _TrailingAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColor.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Icon(icon, size: AppSizes.px20, color: AppColor.greyColor),
          ),
        ),
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
