import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_badges.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_format.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const AppIcon(
                  AppIcons.ticket01,
                  size: 16,
                  color: AppColor.whiteColor,
                ),
              ),
              const SizedBox(width: AppSizes.px10),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColor.whiteColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
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
          const SizedBox(height: AppSizes.px16),
          if (_isPercentage)
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
                    text: '%',
                    style: TextStyle(
                      color: AppColor.whiteColor.withValues(alpha: .9),
                      fontSize: 22,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_2,
                    ),
                  ),
                ],
              ),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  couponCompactNumber(discountValue),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppColor.whiteColor,
                    fontSize: AppFontSizes.size34,
                    fontWeight: AppFontWeights.extraBold,
                    height: AppTextHeights.line1_1,
                    letterSpacing: AppLetterSpacings.spaceNegative0_5,
                  ),
                ),
                const SizedBox(width: AppSizes.px6),
                CurrencyIcon(
                  size: 20,
                  color: AppColor.whiteColor.withValues(alpha: .9),
                ),
              ],
            ),
          const SizedBox(height: AppSizes.px8),
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
            const SizedBox(height: AppSizes.px4),
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
          const SizedBox(height: AppSizes.px16),
          const CouponDashedLine(color: AppColor.white24, height: 1),
          const SizedBox(height: AppSizes.px14),
          _term(icon: AppIcons.tag01, label: scopeLabel, caption: scopeHint),
          const SizedBox(height: AppSizes.px10),
          _term(icon: AppIcons.calendar03, label: windowLabel),
          if (minOrderAmount > 0) ...[
            const SizedBox(height: AppSizes.px10),
            _term(
              icon: AppIcons.shoppingBag01,
              label: S.couponsMinOrder('').trim(),
              money: minOrderAmount,
            ),
          ],
          if (_isPercentage && maxDiscount != null && maxDiscount! > 0) ...[
            const SizedBox(height: AppSizes.px10),
            _term(
              icon: AppIcons.percent,
              label: S.couponsMaxDiscount('').trim(),
              money: maxDiscount,
            ),
          ],
          const SizedBox(height: AppSizes.px10),
          _term(
            icon: AppIcons.refresh,
            label: S.couponsPerCustomer(perUserLimit),
          ),
          const SizedBox(height: AppSizes.px16),
          CouponCodeChip(code: code, onDark: true, onCopy: null),
        ],
      ),
    );
  }

  Widget _term({
    required IconData icon,
    required String label,
    String? caption,
    double? money,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppIcon(icon, size: 14, color: AppColor.whiteColor.withValues(alpha: .8)),
      const SizedBox(width: AppSizes.px8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (money == null)
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
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '$label ${couponMoney(money)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColor.whiteColor,
                        fontSize: AppFontSizes.size10,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.px4),
                  const CurrencyIcon(size: 11, color: AppColor.whiteColor),
                ],
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
