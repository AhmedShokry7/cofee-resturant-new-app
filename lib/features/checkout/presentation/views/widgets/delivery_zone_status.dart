import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/delivery_zone_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColor.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.location,
                size: AppSizes.px18,
                color: AppColor.primaryColor,
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${S.deliveryZoneFromAddress}: ${zone.name}',
                  style: AppFonts.medium14(context)
                      .copyWith(color: AppColor.primaryColor),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            zone.feeMethod == DeliveryFeeMethod.free
                ? deliveryFeeLabel(zone)
                : '${deliveryFeeLabel(zone)}  •  ${Formatters.price(zone.deliveryFee)}',
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.greyColor),
          ),
          if (distance != null) ...[
            SizedBox(height: AppSpacing.xxs),
            Text(
              S.deliveryDistanceAway(distance),
              style: AppFonts.regular12(context)
                  .copyWith(color: AppColor.greyColor),
            ),
          ],
          if (zone.hasFreeDeliveryThreshold) ...[
            SizedBox(height: AppSpacing.xxs),
            Text(
              '${S.deliveryFreeOver} ${Formatters.price(zone.freeDeliveryOver!)}',
              style: AppFonts.regular12(context)
                  .copyWith(color: AppColor.greyColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// "We do not deliver here" — with the two ways out, spelled out.
class OutOfZoneNotice extends StatelessWidget {
  const OutOfZoneNotice({
    super.key,
    required this.canChooseManually,
    this.onChooseManually,
  });

  /// False when the branch serves no zones at all, so there is nothing to pick.
  final bool canChooseManually;
  final VoidCallback? onChooseManually;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColor.errorColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.alert,
                size: AppSizes.px18,
                color: AppColor.errorColor,
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  S.deliveryOutOfZoneShort,
                  style: AppFonts.medium14(context)
                      .copyWith(color: AppColor.errorColor),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            S.deliveryOutOfZone,
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.greyColor),
          ),
          if (canChooseManually && onChooseManually != null) ...[
            SizedBox(height: AppSpacing.sm),
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
