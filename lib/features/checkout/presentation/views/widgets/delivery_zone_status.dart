import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/layout_tokens.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/delivery_zone_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

/// How a zone prices a delivery, in the customer's language.
String deliveryFeeLabel(DeliveryZone zone) => switch (zone.feeMethod) {
  DeliveryFeeMethod.free => S.deliveryAlwaysFree,
  DeliveryFeeMethod.perKm => S.deliveryPerKm,
  DeliveryFeeMethod.fixed => S.deliveryFlatFee,
};

/// The resolved-area card: which zone covers this address and what it costs.
///
/// Before the address was placed on a map this section was a bare dropdown, and
/// the fee shown next to each zone was the flat column value even when the zone
/// charged by distance. Both are shown properly now.
class ResolvedZoneCard extends StatelessWidget {
  const ResolvedZoneCard({super.key, required this.zone});

  final DeliveryZone zone;

  @override
  Widget build(BuildContext context) {
    final distance = zone.distanceKm;
    return Container(
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(LayoutTokens.cardRadius.r),
        border: Border.all(color: AppColor.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedLocation01,
                size: 18.w,
                color: AppColor.primaryColor,
              ),
              SizedBox(width: SpacingTokens.xs.w),
              Expanded(
                child: Text(
                  '${S.deliveryZoneFromAddress}: ${zone.name}',
                  style: AppFonts.medium14(context).copyWith(
                    color: AppColor.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: SpacingTokens.xs.h),
          Text(
            zone.feeMethod == DeliveryFeeMethod.free
                ? deliveryFeeLabel(zone)
                : '${deliveryFeeLabel(zone)}  •  ${Formatters.price(zone.deliveryFee)}',
            style: AppFonts.regular12(context).copyWith(
              color: AppColor.greyColor,
            ),
          ),
          if (distance != null) ...[
            SizedBox(height: 2.h),
            Text(
              S.deliveryDistanceAway(distance),
              style: AppFonts.regular12(context).copyWith(
                color: AppColor.greyColor,
              ),
            ),
          ],
          if (zone.hasFreeDeliveryThreshold) ...[
            SizedBox(height: 2.h),
            Text(
              '${S.deliveryFreeOver} ${Formatters.price(zone.freeDeliveryOver!)}',
              style: AppFonts.regular12(context).copyWith(
                color: AppColor.greyColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "We do not deliver here" — with the two ways out, spelled out.
class OutOfZoneNotice extends StatelessWidget {
  const OutOfZoneNotice({super.key, required this.canChooseManually, this.onChooseManually});

  /// False when the branch serves no zones at all, so there is nothing to pick.
  final bool canChooseManually;
  final VoidCallback? onChooseManually;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LayoutTokens.cardRadius.r),
        border: Border.all(color: AppColor.errorColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedAlert02,
                size: 18.w,
                color: AppColor.errorColor,
              ),
              SizedBox(width: SpacingTokens.xs.w),
              Expanded(
                child: Text(
                  S.deliveryOutOfZoneShort,
                  style: AppFonts.medium14(context).copyWith(
                    color: AppColor.errorColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: SpacingTokens.xs.h),
          Text(
            S.deliveryOutOfZone,
            style: AppFonts.regular12(context).copyWith(
              color: AppColor.greyColor,
            ),
          ),
          if (canChooseManually && onChooseManually != null) ...[
            SizedBox(height: SpacingTokens.sm.h),
            GestureDetector(
              onTap: onChooseManually,
              child: Text(
                S.deliveryChooseZoneManually,
                style: AppFonts.medium12(context).copyWith(
                  color: AppColor.primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}