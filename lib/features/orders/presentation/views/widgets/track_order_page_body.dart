import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/tracking_steps_list.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_status_timeline.dart';

class TrackOrderPageBody extends StatelessWidget {
  const TrackOrderPageBody({super.key, required this.order});

  final OrderItemModel order;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(SpacingTokens.lg.w),
      children: [
        OrderItemCard(product: order.product),
        SizedBox(height: SpacingTokens.lg.h),
        Text("Order Details", style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        const _DetailRow(label: "Expected Deliver Date", value: "03 Sep 2025"),
        SizedBox(height: SpacingTokens.sm.h),
        const _DetailRow(label: "Tracking ID", value: "TRW15415412124212"),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        Text("Order Status", style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        OrderStatusTimeline(steps: getTrackingStepsList()),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppFonts.regular14(
              context,
            ).copyWith(color: AppColor.greyColor),
          ),
        ),
        SizedBox(width: SpacingTokens.sm.w),
        Text(value, style: AppFonts.semiBold16(context)),
      ],
    );
  }
}
