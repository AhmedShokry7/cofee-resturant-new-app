import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_badges.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_format.dart';

/// The coupon exactly as the customer app would show it, used by the editor
/// while the admin is still filling the form.
class CouponPreviewCard extends StatelessWidget {
  const CouponPreviewCard({
    super.key,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.maxDiscount,
    required this.minOrderAmount,
    required this.scopeLabel,
    required this.scopeHint,
    required this.windowLabel,
    required this.perUserLimit,
  });

  final String code;
  final String title;
  final String? description;
  final AdminCouponDiscountType discountType;
  final double discountValue;
  final double? maxDiscount;
  final double minOrderAmount;
  final String scopeLabel;
  final String scopeHint;
  final String windowLabel;
  final int perUserLimit;

  bool get _isPercentage => discountType == AdminCouponDiscountType.percentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [AppColor.sidebarActiveBackground, AppColor.primaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColor.primaryColor.withValues(alpha: .22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColor.whiteColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedTicket01,
                  size: 16,
                  color: AppColor.whiteColor,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  S.couponsPreviewTitle,
                  style: TextStyle(
                    color: AppColor.sidebarMuted,
                    fontSize: AppFontSizes.size9,
                    fontWeight: AppFontWeights.semiBold,
                    letterSpacing: AppLetterSpacings.space0_4,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColor.whiteColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  S.couponsPreviewDiscountLabel,
                  style: const TextStyle(
                    color: AppColor.whiteColor,
                    fontSize: AppFontSizes.size8,
                    fontWeight: AppFontWeights.bold,
                    letterSpacing: AppLetterSpacings.space0_8,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: couponCompactNumber(discountValue),
                  style: const TextStyle(
                    color: AppColor.whiteColor,
                    fontSize: AppFontSizes.size34,
                    fontWeight: AppFontWeights.extraBold,
                    height: AppTextHeights.line1_1,
                    letterSpacing: AppLetterSpacings.spaceNegative0_5,
                  ),
                ),
                TextSpan(
                  text: _isPercentage ? '%' : ' ${S.currency}',
                  style: TextStyle(
                    color: AppColor.whiteColor.withValues(alpha: .9),
                    fontSize: _isPercentage ? 22 : 15,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_2,
                  ),
                ),
              ],
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColor.whiteColor,
              fontSize: AppFontSizes.size13,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_45,
            ),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColor.whiteColor.withValues(alpha: .82),
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_55,
              ),
            ),
          ],
          const SizedBox(height: 15),
          const CouponDashedLine(color: Color(0x3DFFFFFF), height: 1),
          const SizedBox(height: 13),
          _term(
            icon: HugeIcons.strokeRoundedTag01,
            label: scopeLabel,
            caption: scopeHint,
          ),
          const SizedBox(height: 9),
          _term(icon: HugeIcons.strokeRoundedCalendar03, label: windowLabel),
          if (minOrderAmount > 0) ...[
            const SizedBox(height: 9),
            _term(
              icon: HugeIcons.strokeRoundedShoppingBag01,
              label: S.couponsMinOrder(couponMoneyWithCurrency(minOrderAmount)),
            ),
          ],
          if (_isPercentage && maxDiscount != null && maxDiscount! > 0) ...[
            const SizedBox(height: 9),
            _term(
              icon: HugeIcons.strokeRoundedPercent,
              label: S.couponsMaxDiscount(
                couponMoneyWithCurrency(maxDiscount!),
              ),
            ),
          ],
          const SizedBox(height: 9),
          _term(
            icon: HugeIcons.strokeRoundedRefresh,
            label: S.couponsPerCustomer(perUserLimit),
          ),
          const SizedBox(height: 15),
          CouponCodeChip(code: code, onDark: true, onCopy: null),
        ],
      ),
    );
  }

  Widget _term({
    required IconData icon,
    required String label,
    String? caption,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      HugeIcon(
        icon: icon,
        size: 14,
        color: AppColor.whiteColor.withValues(alpha: .8),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColor.whiteColor,
                fontSize: AppFontSizes.size10,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
            if (caption != null)
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColor.whiteColor.withValues(alpha: .66),
                  fontSize: AppFontSizes.size8_5,
                  height: AppTextHeights.line1_4,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
