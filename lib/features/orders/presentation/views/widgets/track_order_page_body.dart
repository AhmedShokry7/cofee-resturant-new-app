import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/tracking_steps_list.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_status_timeline.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/labeled_value_row.dart';

class TrackOrderPageBody extends StatelessWidget {
  const TrackOrderPageBody({super.key, required this.order});

  final OrderItemModel order;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      children: [
OrderItemCard(product: order.product, quantity: order.quantity),
        SizedBox(height: SpacingTokens.lg.h),
        Text("Order Details", style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        if (order.placedAt != null) ...[
          LabeledValueRow(
            label: "Placed",
            value: Formatters.date(order.placedAt!),
            valueSize: 16,
            labelExpanded: true,
          ),
          SizedBox(height: SpacingTokens.sm.h),
        ],
        LabeledValueRow(
          label: "Tracking ID",
          value: order.displayNumber,
          valueSize: 16,
          labelExpanded: true,
        ),
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

