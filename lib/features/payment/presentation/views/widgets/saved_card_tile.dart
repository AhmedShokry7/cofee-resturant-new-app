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

  /// Makes this card the customer's preferred one.
  ///
  /// Null means this row cannot set a preference - the actions available on a
  /// card are then only its own.
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
          width: card.isDefault
              ? AppDimensions.fieldBorderWidthActive
              : AppDimensions.fieldBorderWidth,
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
                    // The brand line is the one that can be long: a card name
                    // and the default badge have to share whatever the two
                    // trailing actions leave, so the name gives way rather than
                    // pushing the badge off the tile.
                    Flexible(
                      child: Text(
                        card.displayBrand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.semiBold16(context),
                      ),
                    ),
                    if (card.isDefault) ...[
                      SizedBox(width: AppSpacing.xs),
                      _DefaultBadge(),
                    ],
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  card.maskedNumber,
                  style: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Text(card.expiry, style: AppFonts.medium14(context)),
          // Every card carries both actions it can answer to. The version here
          // drew one OR the other, so the default card could not be deleted and
          // a second card could not become the default without deleting the
          // first - the two buttons were mutually exclusive by accident.
          if (onSetDefault != null && !card.isDefault)
            _TrailingAction(
              icon: AppIcons.star,
              label: S.setDefaultCard,
              onTap: onSetDefault!,
            ),
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
          // The box is the target: a glyph of twenty inside a square of the
          // accessibility floor, so the last tap on the row is a thumb-sized
          // one and not the icon's own outline.
          child: SizedBox.square(
            dimension: AppDimensions.tapTargetMin,
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
