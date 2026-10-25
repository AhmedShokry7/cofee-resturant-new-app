import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

class OrderDeliveryEstimate extends StatelessWidget {
  const OrderDeliveryEstimate({super.key, this.distanceKm});
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final text = distanceKm == null
        ? S.ordersBranchLocationUnavailable
        : '${S.deliveryDistance}: ${distanceKm!.toStringAsFixed(1)} km  •  '
              '${S.estimatedDelivery}: ${(distanceKm! * 2 + 5).round()} min';
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColor.greyColor),
      ),
    );
  }
}
