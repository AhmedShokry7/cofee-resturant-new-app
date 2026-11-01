import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/layout_tokens.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/order_tracking/order_tracking_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_status_timeline.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/labeled_value_row.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class TrackOrderPageBody extends StatelessWidget {
  const TrackOrderPageBody({super.key, required this.order});

  final OrderItemModel order;

  /// The invoice may be the only identifier a row carries when the order id was
  /// never written back to it.
  String get _orderId => order.orderId.isNotEmpty ? order.orderId : order.id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OrderTrackingCubit(
        repository: context.read<OrdersRepository>(),
        orderId: _orderId,
      )..load(),
      child: _TrackOrderView(order: order),
    );
  }
}

class _TrackOrderView extends StatelessWidget {
  const _TrackOrderView({required this.order});

  final OrderItemModel order;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: LayoutTokens.pageBody(),
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
        BlocBuilder<OrderTrackingCubit, OrderTrackingState>(
          builder: (context, state) {
            if (state.isLoading) {
              // Only the timeline shimmers; the order header above already
              // shows real data and must stay visible.
              return const TrackTimelineSkeleton();
            }
            if (state.failed) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.liveStatusFailed, style: AppFonts.regular14(context)),
                  SizedBox(height: SpacingTokens.sm.h),
                  TextButton(
                    onPressed: () =>
                        context.read<OrderTrackingCubit>().load(),
                    child: Text(S.retry),
                  ),
                ],
              );
            }
            final steps = OrderTrackingSteps.forOrder(
              databaseStatus: order.databaseStatus,
              fulfillmentType: order.fulfillmentType,
              events: state.events ?? const [],
              placedAt: order.placedAt,
            );
            return OrderStatusTimeline(steps: steps);
          },
        ),
      ],
    );
  }
}
