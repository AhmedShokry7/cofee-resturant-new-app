import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';

/// The status of one order, drawn the same way wherever it appears.
///
/// The list card and the receipt page both used to pick their own colour for the
/// same bucket, so a cancelled order could read grey in one place and coffee in
/// another.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status, this.large = false});

  final OrderStatus status;

  /// The receipt page reads its status one step larger than a list row.
  final bool large;

  /// The colour each bucket is known by.
  static Color colorOf(OrderStatus status) => switch (status) {
    OrderStatus.active => AppColor.primaryColor,
    OrderStatus.completed => AppColor.greenColor,
    OrderStatus.cancelled => AppColor.greyColor,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? AppSpacing.md : AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.label,
        style:
            (large ? AppFonts.medium12(context) : AppFonts.regular12(context))
                .copyWith(color: color),
      ),
    );
  }
}
