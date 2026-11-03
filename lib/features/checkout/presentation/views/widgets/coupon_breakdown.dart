import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Why the discount is smaller than the percentage on the coupon.
///
/// 071 made a scoped coupon discount only the eligible lines, which is correct
/// and looks wrong: 20% off cold drinks against a basket that is mostly
/// something else produces a small figure, and a customer cannot see why.
///
/// Collapsed by default so a normal coupon costs no extra taps. Expands to the
/// exact per-line amounts the server approved, and lists the untouched lines so
/// it is clear they were deliberately excluded rather than forgotten.
class CouponBreakdown extends StatefulWidget {
  const CouponBreakdown({super.key, required this.coupon});

  final ValidatedCoupon coupon;

  @override
  State<CouponBreakdown> createState() => _CouponBreakdownState();
}

class _CouponBreakdownState extends State<CouponBreakdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final coupon = widget.coupon;
    final lines = coupon.lines;
    // Nothing to explain: either the server could not break it down, or every
    // line was discounted and the total already tells the story.
    if (lines.isEmpty) return const SizedBox.shrink();
    final discounted = coupon.discountedLines;

    return Container(
      margin: EdgeInsets.only(top: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.surfaceColor,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  AppIcons.discount,
                  size: AppSpacing.lg,
                  color: AppColor.primaryColor,
                ),
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    coupon.isPartial
                        ? '${S.couponEligibleInCart} (${discounted.length}/${lines.length})'
                        : S.couponDiscountBreakdown,
                    style: AppFonts.medium12(context)
                        .copyWith(color: AppColor.primaryColor),
                  ),
                ),
                Icon(
                  _expanded ? AppIcons.arrowUp : AppIcons.arrowDown,
                  size: AppSpacing.lg,
                  color: AppColor.primaryColor,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            SizedBox(height: AppSpacing.sm),
            for (final line in lines)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xs),
                child: _LineRow(line: line),
              ),
            Divider(height: AppSpacing.md, color: AppColor.borderColor),
            Row(
              children: [
                Expanded(
                  child: Text(
                    S.subTotalDiscounted,
                    style: AppFonts.medium12(context),
                  ),
                ),
                PriceLabel(
                  amount: coupon.discount,
                  prefix: '-',
                  style: AppFonts.medium12(context)
                      .copyWith(color: AppColor.primaryColor),
                  iconSize: 12,
                  iconColor: AppColor.primaryColor,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final CouponLineDiscount line;

  @override
  Widget build(BuildContext context) {
    final touched = line.discount > 0;
    return Row(
      children: [
        Icon(
          touched ? AppIcons.checkmarkCircle : AppIcons.minus,
          size: AppSizes.px14,
          color: touched ? AppColor.primaryColor : AppColor.greyColor,
        ),
        SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.regular12(context)
                    .copyWith(color: touched ? null : AppColor.greyColor),
              ),
              // Why an untouched line has no discount. Without it the greyed row
              // reads as a mistake.
              if (!touched && !line.isEligible)
                Text(
                  S.couponLineNotIncluded,
                  style: AppFonts.regular12(context).copyWith(
                    color: AppColor.greyColor,
                    fontSize: AppFontSizes.size10,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.xs),
        if (touched)
          PriceLabel(
            amount: line.discount,
            prefix: '-',
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.primaryColor),
            iconSize: 11,
            iconColor: AppColor.primaryColor,
          )
        else
          Text(
            Formatters.price(line.lineTotal),
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.greyColor),
          ),
      ],
    );
  }
}
