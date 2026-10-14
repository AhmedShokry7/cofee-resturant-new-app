import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/leave_review_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

/// Full order data (big-app pattern): tapping an order opens its details,
/// and tracking/review branch out from here.
class OrderDetailsPage extends StatelessWidget {
  const OrderDetailsPage({super.key, required this.order});

  static const routeName = "orderDetailsRoute";

  final OrderItemModel order;

  void _onAction(BuildContext context) {
    if (order.status == OrderStatus.active) {
      Navigator.of(
        context,
      ).pushNamed(TrackOrderPage.routeName, arguments: order);
    } else if (order.status == OrderStatus.completed) {
      Navigator.of(
        context,
      ).pushNamed(LeaveReviewPage.routeName, arguments: order);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-reads the order so cancelling from tracking reflects here on return.
    // Falls back to the passed order when no OrdersCubit is above.
    OrderItemModel? fresh;
    try {
      final orders = context.watch<OrdersCubit>().state.orders;
      for (final item in orders) {
        if (item.id == order.id) {
          fresh = item;
          break;
        }
      }
    } catch (_) {
      fresh = null;
    }
    final current = fresh ?? order;
    return _DetailsScaffold(order: current, onAction: _onAction);
  }
}

class _DetailsScaffold extends StatelessWidget {
  const _DetailsScaffold({required this.order, required this.onAction});

  final OrderItemModel order;
  final void Function(BuildContext context) onAction;

  Color _statusColor(BuildContext context) {
    switch (order.status) {
      case OrderStatus.active:
        return AppColor.primaryColor;
      case OrderStatus.completed:
        return AppColor.greenColor;
      case OrderStatus.cancelled:
        return AppColor.greyColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = order.product.price * order.quantity;
    return Scaffold(
      appBar: AppBar(title: const Text("Order Details")),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          SpacingTokens.lg.w,
          SpacingTokens.md.h,
          SpacingTokens.lg.w,
          SpacingTokens.lg.w,
        ),
        children: [
          Row(
            children: [
              Text(
                "Order #${order.id}",
                style: AppFonts.semiBold18(context),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SpacingTokens.md.w,
                  vertical: SpacingTokens.xs.h,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100.r),
                ),
                child: Text(
                  order.status.label,
                  style: AppFonts.medium12(
                    context,
                  ).copyWith(color: _statusColor(context)),
                ),
              ),
            ],
          ),
          SizedBox(height: SpacingTokens.lg.h),
          Container(
            padding: EdgeInsets.all(SpacingTokens.md.w),
            decoration: BoxDecoration(
              color: AppColor.whiteColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColor.borderColor),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Image.asset(
                    order.product.image,
                    height: 72.w,
                    width: 72.w,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: SpacingTokens.md.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.product.category,
                        style: AppFonts.regular12(
                          context,
                        ).copyWith(color: AppColor.greyColor),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        order.product.name,
                        style: AppFonts.semiBold16(context),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "Qty: ${order.quantity}",
                        style: AppFonts.regular14(
                          context,
                        ).copyWith(color: AppColor.greyColor),
                      ),
                    ],
                  ),
                ),
                Text(
                  Formatters.price(total),
                  style: AppFonts.semiBold16(
                    context,
                  ).copyWith(color: AppColor.primaryColor),
                ),
              ],
            ),
          ),
          SizedBox(height: SpacingTokens.lg.h),
          _DetailRow(
            label: "Items count",
            value: "${order.quantity}",
          ),
          SizedBox(height: SpacingTokens.sm.h),
          _DetailRow(
            label: "Total",
            value: Formatters.price(total),
            highlighted: true,
          ),
        ],
      ),
      bottomNavigationBar:
          order.status == OrderStatus.cancelled
              ? null
              : Container(
                  padding: EdgeInsets.all(SpacingTokens.lg.w),
                  decoration: const BoxDecoration(
                    color: AppColor.whiteColor,
                    border: Border(
                      top: BorderSide(color: AppColor.borderColor),
                    ),
                  ),
                  child: CustomBtn(
                    text: order.status == OrderStatus.active
                        ? "Track Order"
                        : "Leave Review",
                    onPressed: () => onAction(context),
                  ),
                ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.regular14(
            context,
          ).copyWith(color: AppColor.greyColor),
        ),
        Text(
          value,
          style: AppFonts.semiBold16(context).copyWith(
            color: highlighted
                ? AppColor.primaryColor
                : AppColor.blackColor,
          ),
        ),
      ],
    );
  }
}
