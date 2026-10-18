import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_status_timeline.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/labeled_value_row.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class TrackOrderPageBody extends StatefulWidget {
  const TrackOrderPageBody({super.key, required this.order});

  final OrderItemModel order;

  @override
  State<TrackOrderPageBody> createState() => _TrackOrderPageBodyState();
}

class _TrackOrderPageBodyState extends State<TrackOrderPageBody> {
  late final Future<List<OrderStatusEvent>> _historyFuture;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    final orderId = order.orderId.isNotEmpty ? order.orderId : order.id;
    _historyFuture = context.read<OrdersRepository>().orderHistory(orderId);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      children: [
        OrderItemCard(
          product: order.product,
          quantity: order.quantity,
          note: order.note,
          unitPrice: order.chargedUnit,
        ),
        SizedBox(height: SpacingTokens.lg.h),
        Text(S.orderDetails, style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        if (order.placedAt != null) ...[
          LabeledValueRow(
            label: S.placed,
            value: Formatters.date(order.placedAt!),
            valueSize: 16,
            labelExpanded: true,
          ),
          SizedBox(height: SpacingTokens.sm.h),
        ],
        LabeledValueRow(
          label: S.trackingId,
          value: order.displayNumber,
          valueSize: 16,
          labelExpanded: true,
        ),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        Text(S.orderStatus, style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        FutureBuilder<List<OrderStatusEvent>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Only the timeline shimmers; the order header above already
              // shows real data and must stay visible.
              return const TrackTimelineSkeleton();
            }
            if (snapshot.hasError) {
              // The provider's error text is English and technical; the
              // customer only needs to know it did not load.
              return Text(
                S.liveStatusFailed,
                style: AppFonts.regular14(context),
              );
            }
            final steps = OrderTrackingSteps.forOrder(
              databaseStatus: order.databaseStatus,
              fulfillmentType: order.fulfillmentType,
              events: snapshot.data ?? const [],
              placedAt: order.placedAt,
            );
            return OrderStatusTimeline(steps: steps);
          },
        ),
      ],
    );
  }
}
