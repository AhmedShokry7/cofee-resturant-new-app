import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/leave_review_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/labeled_value_row.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

/// Full order data (big-app pattern): tapping an order opens its details,
/// and tracking/review branch out from here.
class OrderDetailsPage extends StatelessWidget {
  const OrderDetailsPage({super.key, required this.order, this.lines});

  static const routeName = "orderDetailsRoute";

  final OrderItemModel order;
  final List<OrderItemModel>? lines;

  void _onAction(BuildContext context) {
    if (order.status == OrderStatus.active) {
      Navigator.of(context)
          .pushNamed(TrackOrderPage.routeName, arguments: order);
    } else if (order.status == OrderStatus.completed) {
      Navigator.of(context)
          .pushNamed(LeaveReviewPage.routeName, arguments: order);
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
    return _DetailsScaffold(order: current, lines: lines, onAction: _onAction);
  }
}

class _DetailsScaffold extends StatelessWidget {
  const _DetailsScaffold({
    required this.order,
    this.lines,
    required this.onAction,
  });

  final OrderItemModel order;
  final List<OrderItemModel>? lines;
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
    final allLines = lines ??
        (() {
          try {
            final orders = context.read<OrdersCubit>().state.orders;
            final found = orders
                .where(
                  (o) =>
                      o.orderId ==
                      (order.orderId.isNotEmpty ? order.orderId : order.id),
                )
                .toList();
            if (found.isNotEmpty) return found;
          } catch (_) {}
          return <OrderItemModel>[order];
        })();
    final totalItems = allLines.fold<int>(0, (sum, line) => sum + line.quantity);
    final total = order.grandTotal ??
        allLines.fold<double>(0.0, (sum, line) => sum + line.chargedTotal);
    return Scaffold(
      appBar: AppBar(title: Text(S.orderDetails)),
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
                S.orderNumber(order.displayNumber),
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
                  style: AppFonts.medium12(context)
                      .copyWith(color: _statusColor(context)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < allLines.length; i++) ...[
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: SizedBox(
                          height: 72.w,
                          width: 72.w,
                          child: ProductImageView(product: allLines[i].product),
                        ),
                      ),
                      SizedBox(width: SpacingTokens.md.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allLines[i].product.category,
                              style: AppFonts.regular12(context)
                                  .copyWith(color: AppColor.greyColor),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              allLines[i].product.name,
                              style: AppFonts.semiBold16(context),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              S.quantityLabel(allLines[i].quantity),
                              style: AppFonts.regular14(context)
                                  .copyWith(color: AppColor.greyColor),
                            ),
                          ],
                        ),
                      ),
                      PriceLabel(
                        amount: allLines[i].chargedTotal,
                        style: AppFonts.semiBold16(context)
                            .copyWith(color: AppColor.primaryColor),
                        iconSize: 16,
                        iconColor: AppColor.primaryColor,
                      ),
                    ],
                  ),
                  if (allLines[i].lineDiscountTotal != null &&
                      allLines[i].lineDiscountTotal! > 0) ...[
                    SizedBox(height: SpacingTokens.xs.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          HugeIcons.strokeRoundedDiscount01,
                          size: 12.w,
                          color: AppColor.primaryColor,
                        ),
                        SizedBox(width: SpacingTokens.xs.w),
                        Text(
                          S.lineDiscount,
                          style: AppFonts.regular12(context)
                              .copyWith(color: AppColor.primaryColor),
                        ),
                        SizedBox(width: SpacingTokens.xs.w),
                        PriceLabel(
                          amount: allLines[i].lineDiscountTotal!,
                          prefix: '-',
                          style: AppFonts.regular12(context)
                              .copyWith(color: AppColor.primaryColor),
                          iconSize: 11,
                          iconColor: AppColor.primaryColor,
                        ),
                      ],
                    ),
                  ],
                  if (i != allLines.length - 1)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: SpacingTokens.sm.h),
                      child: Divider(color: AppColor.borderColor),
                    ),
                ],
              ],
            ),
          ),
          SizedBox(height: SpacingTokens.lg.h),
          if (order.isDelivery) ...[
            LabeledValueRow(
              label: S.fulfillmentMethod,
              value: S.deliveryMethod,
              valueSize: 16,
              labelExpanded: true,
            ),
            if (order.deliveryZoneName != null) ...[
              SizedBox(height: SpacingTokens.sm.h),
              LabeledValueRow(
                label: S.deliveryZone,
                value: order.deliveryZoneName!,
                valueSize: 16,
                labelExpanded: true,
              ),
            ],
            if (order.deliveryAddress != null) ...[
              SizedBox(height: SpacingTokens.sm.h),
              LabeledValueRow(
                label: S.shippingAddress,
                value: order.deliveryAddress!,
                valueSize: 16,
                labelExpanded: true,
              ),
            ],
            if (order.deliveryFee > 0) ...[
              SizedBox(height: SpacingTokens.sm.h),
              LabeledValueRow(
                label: S.deliveryFee,
                priceValue: order.deliveryFee,
                valueSize: 16,
              ),
            ],
            SizedBox(height: SpacingTokens.lg.h),
          ],
          LabeledValueRow(
            label: S.itemsCount,
            value: "$totalItems",
            valueSize: 16,
            labelExpanded: true,
          ),
          if (order.discountTotal != null && order.discountTotal! > 0) ...[
            SizedBox(height: SpacingTokens.sm.h),
            LabeledValueRow(
              label: S.couponDiscount,
              priceValue: order.discountTotal!,
              pricePrefix: '-',
              valueSize: 16,
            ),
          ],
          SizedBox(height: SpacingTokens.sm.h),
          LabeledValueRow(
            label: S.total,
            priceValue: total,
            emphasized: true,
            valueSize: 16,
          ),
        ],
      ),
      bottomNavigationBar: order.status == OrderStatus.cancelled
          ? null
          : Container(
              padding: EdgeInsets.all(SpacingTokens.lg.w),
              decoration: const BoxDecoration(
                color: AppColor.whiteColor,
                border: Border(top: BorderSide(color: AppColor.borderColor)),
              ),
              child: CustomBtn(
                text: order.status == OrderStatus.active
                    ? S.trackOrder
                    : S.leaveReview,
                onPressed: () => onAction(context),
              ),
            ),
    );
  }
}
