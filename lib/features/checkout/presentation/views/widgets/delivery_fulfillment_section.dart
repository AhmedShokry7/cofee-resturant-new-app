import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/delivery_zone_model.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';

/// Pickup vs delivery, and the delivery zone when delivery is chosen.
///
/// Delivery is only selectable when the selected branch serves at least one
/// active zone. When it is unavailable, tapping "delivery" is refused with an
/// immediate message and an inline explanation, and checkout stays blocked until
/// the shopper explicitly chooses pickup, so a pickup order is never placed by
/// someone who thinks they chose delivery.
class DeliveryFulfillmentSection extends StatelessWidget {
  const DeliveryFulfillmentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, state) {
        final cubit = context.read<CheckoutCubit>();
        final deliveryUnavailable = state.deliveryZones.isEmpty;
        final unavailableMessage = state.deliveryZonesLoadFailed
            ? S.deliveryUnavailableError
            : S.deliveryUnavailable;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.fulfillmentMethod, style: AppFonts.semiBold16(context)),
            SizedBox(height: SpacingTokens.md.h),
            Row(
              children: [
                Expanded(
                  child: _FulfillmentOption(
                    label: S.pickupMethod,
                    selected: !state.fulfillment.isDelivery,
                    onTap: () => cubit.setFulfillment(FulfillmentType.pickup),
                  ),
                ),
                SizedBox(width: SpacingTokens.sm.w),
                Expanded(
                  child: _FulfillmentOption(
                    label: S.deliveryMethod,
                    selected: state.fulfillment.isDelivery,
                    enabled: !deliveryUnavailable,
                    onTap: () => _requestDelivery(context, cubit),
                  ),
                ),
              ],
            ),
            if (deliveryUnavailable) ...[
              SizedBox(height: SpacingTokens.md.h),
              Text(
                unavailableMessage,
                style: AppFonts.regular14(context)
                    .copyWith(color: AppColor.greyColor),
              ),
            ] else if (state.fulfillment.isDelivery) ...[
              SizedBox(height: SpacingTokens.md.h),
              _DeliveryZoneField(zones: state.deliveryZones),
            ],
          ],
        );
      },
    );
  }

  /// Attempts to switch to delivery and, when it is refused, tells the shopper
  /// right away why instead of leaving them on a silent pickup fallback.
  void _requestDelivery(BuildContext context, CheckoutCubit cubit) {
    final messenger = ScaffoldMessenger.of(context);
    final applied = cubit.setFulfillment(FulfillmentType.delivery);
    if (applied) return;
    final message = cubit.state.orderError;
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _FulfillmentOption extends StatelessWidget {
  const _FulfillmentOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColor.primaryColor : AppColor.whiteColor,
            border: Border.all(
              color: selected ? AppColor.primaryColor : AppColor.borderColor,
            ),
            borderRadius: BorderRadius.circular(100.r),
          ),
          child: Text(
            label,
            style: AppFonts.medium14(context).copyWith(
              color: selected ? AppColor.whiteColor : AppColor.greyColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryZoneField extends StatelessWidget {
  const _DeliveryZoneField({required this.zones});

  final List<DeliveryZone> zones;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CheckoutCubit>();
    final selected = context.select<CheckoutCubit, DeliveryZone?>(
      (value) => value.state.selectedDeliveryZone,
    );
    final value = zones.contains(selected) ? selected : zones.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.deliveryZone, style: AppFonts.regular14(context)),
        SizedBox(height: SpacingTokens.xs.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: SpacingTokens.md.w),
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.borderColor),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: DropdownButton<DeliveryZone>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: Text(S.selectDeliveryZone),
            items: [
              for (final zone in zones)
                DropdownMenuItem<DeliveryZone>(
                  value: zone,
                  child: Text(
                    '${zone.name}  •  ${zone.deliveryFee.toStringAsFixed(2)}',
                    style: AppFonts.regular14(context),
                  ),
                ),
            ],
            onChanged: (zone) {
              if (zone != null) cubit.selectDeliveryZone(zone);
            },
          ),
        ),
      ],
    );
  }
}
