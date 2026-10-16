import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';

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
        margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
        padding: EdgeInsets.all(SpacingTokens.md.w),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: SizedBox(
                height: 56.w,
                width: 56.w,
                child: ProductImageView(product: reward.product),
              ),
            ),
            SizedBox(width: SpacingTokens.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.product.name,
                    style: AppFonts.semiBold16(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    S.points(reward.pointsCost),
                    style: AppFonts.medium14(context)
                        .copyWith(color: AppColor.primaryColor),
                  ),
                ],
              ),
            ),
            SizedBox(width: SpacingTokens.sm.w),
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
                    horizontal: SpacingTokens.lg.w,
                    vertical: SpacingTokens.sm.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColor.primaryColor,
                    borderRadius: BorderRadius.circular(100.r),
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
