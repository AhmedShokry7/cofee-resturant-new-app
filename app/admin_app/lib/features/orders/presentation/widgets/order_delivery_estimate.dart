import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderDeliveryEstimate extends StatelessWidget {
  const OrderDeliveryEstimate({super.key, this.distanceKm});

  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = distanceKm == null
        ? S.ordersBranchLocationUnavailable
        : '${S.deliveryDistance}: '
              '${localizeDigits(distanceKm!.toStringAsFixed(1))} km  •  '
              '${S.estimatedDelivery}: '
              '${localizeDigits('${(distanceKm! * 2 + 5).round()}')} min';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: adminMutedColor(theme),
          fontSize: AppFontSizes.size10,
          height: AppTextHeights.line1_5,
        ),
      ),
    );
  }
}
