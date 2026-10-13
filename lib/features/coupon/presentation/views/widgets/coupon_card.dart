import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';

class CouponCard extends StatelessWidget {
  const CouponCard({super.key, required this.coupon});

  final CouponModel coupon;

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: coupon.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Code ${coupon.code} copied")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: SpacingTokens.lg.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(SpacingTokens.md.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44.w,
                  width: 44.w,
                  decoration: BoxDecoration(
                    color: AppColor.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    HugeIcons.strokeRoundedDiscountTag01,
                    color: AppColor.primaryColor,
                    size: 22.w,
                  ),
                ),
                SizedBox(width: SpacingTokens.md.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coupon.title, style: AppFonts.semiBold16(context)),
                      SizedBox(height: 4.h),
                      Text(
                        coupon.description,
                        style: AppFonts.regular12(
                          context,
                        ).copyWith(color: AppColor.greyColor),
                      ),
                      SizedBox(height: SpacingTokens.sm.h),
                      Row(
                        children: [
                          Icon(
                            HugeIcons.strokeRoundedDiscount01,
                            size: 18.w,
                            color: AppColor.blackColor,
                          ),
                          SizedBox(width: SpacingTokens.xs.w),
                          Text(
                            coupon.discount,
                            style: AppFonts.medium14(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _copyCode(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              color: AppColor.lightGreyColor,
              padding: EdgeInsets.symmetric(vertical: SpacingTokens.md.h),
              child: Center(
                child: Text(
                  "Copy Code",
                  style: AppFonts.medium16(
                    context,
                  ).copyWith(color: AppColor.primaryColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
