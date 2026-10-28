import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/models/order_status.dart';

class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status, this.dense = false});

  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final view = OrderStatusView.of(status);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark
        ? Color.lerp(view.color, AppColor.whiteColor, .35)!
        : view.color;
    final background = dark
        ? view.color.withValues(alpha: .16)
        : Color.lerp(view.color, AppColor.whiteColor, .86)!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 8,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: view.color.withValues(alpha: dark ? .35 : .18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              view.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: dense ? 9 : 9.5,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.px6),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: foreground,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
        ],
      ),
    );
  }
}
