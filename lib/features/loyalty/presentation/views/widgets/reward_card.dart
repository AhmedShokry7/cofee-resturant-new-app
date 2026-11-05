import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class RewardCard extends StatelessWidget {
  const RewardCard({
    super.key,
    required this.reward,
    required this.locked,
    this.busy = false,
    this.onRedeem,
  });

  final RewardModel reward;
  final bool locked;

  /// Another reward is being spent, so this card cannot start a second spend.
  final bool busy;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    // A reward that cannot be redeemed yet is set below the redeemable ones by
    // its own surface, never by an Opacity over the subtree: dimming the whole
    // card to 55% takes the title and the points cost below the contrast a
    // customer needs to read them.
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: locked ? AppColor.lightGreyColor : AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            child: SizedBox(
              height: AppSizes.px56,
              width: AppSizes.px56,
              child: _RewardThumb(reward: reward, muted: locked),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.name,
                  style: AppFonts.semiBold16(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (reward.type != RewardTargetType.product) ...[
                      _RewardTypeBadge(type: reward.type, muted: locked),
                      SizedBox(width: AppSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        S.points(reward.pointsCost),
                        style: AppFonts.medium14(context)
                            .copyWith(color: AppColor.primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          if (locked)
            Text(
              S.locked,
              style: AppFonts.medium14(context)
                  .copyWith(color: AppColor.iconOnLight),
            )
          else
            Semantics(
              button: true,
              // Naming the reward as well as the action, because several of
              // these cards sit one under another.
              label: '${S.redeem}: ${reward.name}',
              child: Material(
                color: AppColor.primaryColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  // The spend this tap starts is already in flight.
                  onTap: busy ? null : onRedeem,
                  // Ink that stops at the pill instead of splashing a
                  // rectangle behind rounded ends.
                  customBorder: const StadiumBorder(),
                  child: Container(
                    alignment: Alignment.center,
                    // The pill is the only way to spend this reward, so it is a
                    // full target rather than a line of text.
                    constraints: const BoxConstraints(
                      minHeight: AppDimensions.tapTargetMin,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Text(
                      S.redeem,
                      style: AppFonts.medium14(context)
                          .copyWith(color: AppColor.whiteColor),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardThumb extends StatelessWidget {
  const _RewardThumb({required this.reward, required this.muted});

  final RewardModel reward;

  /// A reward that is not available yet has its picture pushed back; its words
  /// stay at full strength.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final iconColor = muted ? AppColor.greyColor : AppColor.primaryColor;
    final product = reward.product;
    if (product != null) return ProductImageView(product: product);
    final image = reward.image;
    if (image != null) return DbImage(image: image, iconSize: AppSizes.px22);
    return ColoredBox(
      color: AppColor.primaryColor.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          _rewardTypeIcon(reward.type),
          color: iconColor,
          size: AppIconSize.xxl,
        ),
      ),
    );
  }
}

class _RewardTypeBadge extends StatelessWidget {
  const _RewardTypeBadge({required this.type, required this.muted});

  final RewardTargetType type;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tint = muted ? AppColor.greyColor : AppColor.primaryColor;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + AppSpacing.xxs,
        vertical: AppSizes.px1,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.r6),
      ),
      child: Text(
        switch (type) {
          RewardTargetType.bundle => S.bundleLabel,
          RewardTargetType.plan => S.subscriptionLabel,
          RewardTargetType.product => '',
        },
        style: AppFonts.regular12(context)
            .copyWith(color: tint, fontWeight: AppFontWeights.semiBold),
      ),
    );
  }
}

IconData _rewardTypeIcon(RewardTargetType type) => switch (type) {
  RewardTargetType.product => AppIcons.coffee,
  RewardTargetType.bundle => AppIcons.gift,
  RewardTargetType.plan => AppIcons.refresh,
};
