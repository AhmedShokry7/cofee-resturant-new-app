import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';

class CouponCard extends StatelessWidget {
  const CouponCard({super.key, required this.coupon, this.isApplied = false});

  final CouponModel coupon;

  /// Highlights the code currently attached to the cart.
  final bool isApplied;

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: coupon.code));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.codeCopied(coupon.code))));
  }

  /// One line telling the customer where they stand with this coupon.
  ///
  /// The list used to look identical for every customer, so a code the shopper
  /// had already spent their allowance on looked available right up until the
  /// checkout refused it.
  String? _statusLine() {
    if (coupon.isExhaustedForMe) return S.couponNoUsesLeft;
    final remaining = coupon.remainingUses;
    if (remaining == null) return null;
    return S.couponUsesLeft(remaining);
  }

  @override
  Widget build(BuildContext context) {
    final exhausted = coupon.isExhaustedForMe;
    final status = _statusLine();
    // Greyed rather than removed: a coupon the customer cannot use right now
    // is information, and deleting it is what made this look like a bug.
    final accent = exhausted ? AppColor.greyColor : AppColor.primaryColor;

    return Container(
      margin: EdgeInsets.only(bottom: SpacingTokens.lg.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isApplied ? AppColor.primaryColor : AppColor.borderColor,
          width: isApplied ? 1.5 : 1,
        ),
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
                    color: accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    HugeIcons.strokeRoundedDiscountTag01,
                    color: accent,
                    size: 22.w,
                  ),
                ),
                SizedBox(width: SpacingTokens.md.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.title,
                        style: AppFonts.semiBold16(context).copyWith(
                          color: exhausted ? AppColor.greyColor : null,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        coupon.description,
                        style: AppFonts.regular12(context)
                            .copyWith(color: AppColor.greyColor),
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
                            style: AppFonts.medium14(context).copyWith(
                              color: exhausted ? AppColor.greyColor : null,
                            ),
                          ),
                        ],
                      ),
                      if (isApplied || status != null) ...[
                        SizedBox(height: SpacingTokens.sm.h),
                        _StatusChip(
                          label: isApplied ? S.couponAppliedBadge : status!,
                          color: isApplied ? AppColor.primaryColor : accent,
                        ),
                      ],
                      // Naming the scope is what turns "this code did not work"
                      // into "this code is for espresso". Without it a scoped
                      // coupon is indistinguishable from an unscoped one until
                      // it is refused.
                      if (coupon.isScoped) ...[
                        SizedBox(height: SpacingTokens.xs.h),
                        Text(
                          '${S.couponAppliesTo} ${coupon.scopeLabel}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.regular12(context).copyWith(
                            color: AppColor.greyColor,
                          ),
                        ),
                        // The server discounts only these lines, so the figure
                        // above is a share of *these* items and not of the whole
                        // basket. Saying it prevents "why is the discount so
                        // small" tickets.
                        SizedBox(height: 2.h),
                        Text(
                          S.couponScopeDiscountNote,
                          style: AppFonts.regular12(context).copyWith(
                            color: AppColor.greyColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            // Copying a code the customer cannot use would only set them up
            // for the same failure later.
            onTap: exhausted ? null : () => _copyCode(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              color: exhausted ? AppColor.surfaceColor : AppColor.lightGreyColor,
              padding: EdgeInsets.symmetric(vertical: SpacingTokens.md.h),
              child: Center(
                child: Text(
                  exhausted ? S.couponNoUsesLeft : S.copyCode,
                  style: AppFonts.medium16(context).copyWith(
                    color: exhausted ? AppColor.greyColor : AppColor.primaryColor,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: AppFonts.medium12(context).copyWith(color: color),
      ),
    );
  }
}
