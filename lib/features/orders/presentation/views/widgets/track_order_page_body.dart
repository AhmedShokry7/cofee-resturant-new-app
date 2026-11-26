import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/order_tracking/order_tracking_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_status_timeline.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/labeled_value_row.dart';
import 'package:new_coffee/shared/widgets/app_icon.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
      padding: AppLayout.pageBody,
      children: [
        OrderItemCard(
          product: order.product,
          quantity: order.quantity,
          note: order.note,
          unitPrice: order.chargedUnit,
        ),
        if (order.isDelivery &&
            order.deliveryEstimatedMinutes != null &&
            order.placedAt != null) ...[
          SizedBox(height: AppSpacing.md),
          _EstimatedArrival(order: order),
        ],
        SizedBox(height: AppSpacing.lg),
        Text(S.orderDetails, style: AppFonts.semiBold16(context)),
        SizedBox(height: AppSpacing.md),
        if (order.placedAt != null) ...[
          LabeledValueRow(
            label: S.placed,
            value: Formatters.date(order.placedAt!),
            valueSize: 16,
            labelExpanded: true,
          ),
          SizedBox(height: AppSpacing.sm),
        ],
        LabeledValueRow(
          label: S.trackingId,
          value: order.displayNumber,
          valueSize: 16,
          labelExpanded: true,
        ),
        SizedBox(height: AppSpacing.lg),
        const Divider(),
        SizedBox(height: AppSpacing.lg),
        Text(S.orderStatus, style: AppFonts.semiBold16(context)),
        SizedBox(height: AppSpacing.md),
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
                  SizedBox(height: AppSpacing.sm),
                  CustomTextButton(
                    onPressed: () => context.read<OrderTrackingCubit>().load(),
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

class _EstimatedArrival extends StatelessWidget {
  const _EstimatedArrival({required this.order});

  final OrderItemModel order;

  @override
  Widget build(BuildContext context) {
    final estimate = order.placedAt!.add(
      Duration(minutes: order.deliveryEstimatedMinutes!),
    );
    final time = TimeOfDay.fromDateTime(estimate).format(context);
    final text = '${Formatters.date(estimate)} · $time';
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer
            .withValues(alpha: .45),
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(AppIcons.clock),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  S.estimatedDelivery,
                  style: AppFonts.semiBold14(context),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(text, style: AppFonts.semiBold16(context)),
          SizedBox(height: AppSpacing.xxs),
          Text(S.estimatedDeliveryNote, style: AppFonts.regular12(context)),
        ],
      ),
    );
  }
}
