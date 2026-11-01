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
    this.onRedeem,
  });

  final RewardModel reward;
  final bool locked;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.md),
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
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
                child: _RewardThumb(reward: reward),
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
                        _RewardTypeBadge(type: reward.type),
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
                    .copyWith(color: AppColor.greyColor),
              )
            else
              GestureDetector(
                onTap: onRedeem,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColor.primaryColor,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    S.redeem,
                    style: AppFonts.medium14(context)
                        .copyWith(color: AppColor.whiteColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RewardThumb extends StatelessWidget {
  const _RewardThumb({required this.reward});

  final RewardModel reward;

  @override
  Widget build(BuildContext context) {
    final product = reward.product;
    if (product != null) return ProductImageView(product: product);
    final image = reward.image;
    if (image != null) return DbImage(image: image, iconSize: 22);
    return ColoredBox(
      color: AppColor.primaryColor.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          _rewardTypeIcon(reward.type),
          color: AppColor.primaryColor,
          size: AppSpacing.xl,
        ),
      ),
    );
  }
}

class _RewardTypeBadge extends StatelessWidget {
  const _RewardTypeBadge({required this.type});

  final RewardTargetType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + AppSpacing.xxs,
        vertical: AppSizes.px1,
      ),
      decoration: BoxDecoration(
        color: AppColor.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.r6),
      ),
      child: Text(
        switch (type) {
          RewardTargetType.bundle => S.bundleLabel,
          RewardTargetType.plan => S.subscriptionLabel,
          RewardTargetType.product => '',
        },
        style: AppFonts.regular12(context).copyWith(
          color: AppColor.primaryColor,
          fontWeight: AppFontWeights.semiBold,
        ),
      ),
    );
  }
}

IconData _rewardTypeIcon(RewardTargetType type) => switch (type) {
  RewardTargetType.product => AppIcons.coffee,
  RewardTargetType.bundle => AppIcons.gift,
  RewardTargetType.plan => AppIcons.refresh,
};
