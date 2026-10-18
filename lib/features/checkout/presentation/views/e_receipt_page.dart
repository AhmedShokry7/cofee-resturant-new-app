import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/order_model.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

class EReceiptPage extends StatelessWidget {
  const EReceiptPage({super.key});

  static const routeName = "eReceiptRoute";

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CheckoutCubit>().state;
    final order = state.lastOrder;

    return Scaffold(
      appBar: AppBar(title: Text(S.eReceipt)),
      body: order == null
          ? EmptyState(
              icon: HugeIcons.strokeRoundedReceiptDollar,
              title: S.noReceipt,
              subtitle: S.receiptHint,
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.lg.w,
                SpacingTokens.md.h,
                SpacingTokens.lg.w,
                SpacingTokens.lg.w,
              ),
              children: [
                _ReceiptCard(order: order),
                SizedBox(height: SpacingTokens.lg.h),
                _InfoCard(
                  label: S.fulfillmentMethod,
                  value: order.isDelivery ? S.deliveryMethod : S.pickupMethod,
                ),
                if (order.isDelivery && order.deliveryZoneName != null) ...[
                  SizedBox(height: SpacingTokens.md.h),
                  _InfoCard(
                    label: S.deliveryZone,
                    value: order.deliveryZoneName!,
                  ),
                ],
                if (order.isDelivery && order.deliveryAddress != null) ...[
                  SizedBox(height: SpacingTokens.md.h),
                  _InfoCard(
                    label: S.shippingAddress,
                    value: order.deliveryAddress!,
                  ),
                ],
                SizedBox(height: SpacingTokens.md.h),
                _InfoCard(
                  label: S.paymentMethod,
                  value: state.selectedPaymentMethod?.label ?? '—',
                ),
              ],
            ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SpacingTokens.lg.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedReceiptDollar,
                size: 24.w,
                color: AppColor.primaryColor,
              ),
              SizedBox(width: SpacingTokens.sm.w),
              Expanded(
                child: Text(
                  S.eReceipt,
                  style: AppFonts.semiBold18(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: SpacingTokens.sm.w),
              Text(
                order.id,
                style: AppFonts.medium14(context)
                    .copyWith(color: AppColor.greyColor),
              ),
            ],
          ),
          SizedBox(height: SpacingTokens.xs.h),
          Text(
            Formatters.date(order.date),
            style: AppFonts.regular14(context)
                .copyWith(color: AppColor.greyColor),
          ),
          SizedBox(height: SpacingTokens.md.h),
          const Divider(),
          ...order.items.map(
            (item) => Padding(
              padding: EdgeInsets.symmetric(vertical: SpacingTokens.sm.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${item.quantity} × ${item.product.name}",
                          style: AppFonts.regular14(context),
                        ),
                      ),
                      PriceLabel(
                        amount: item.total,
                        style: AppFonts.medium14(context),
                        iconSize: 14,
                      ),
                    ],
                  ),
                  // Per-line coupon attribution, when the server could break
                  // the discount down. Only lines that actually got a share are
                  // shown, so a normal coupon costs no extra space.
                  if (order.discountLines.isNotEmpty) ...[
                    for (final line in order.discountLines)
                      if (line.productId == item.product.id &&
                          line.discount > 0)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 2.h,
                            left: SpacingTokens.md.w,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                HugeIcons.strokeRoundedDiscount01,
                                size: 12.w,
                                color: AppColor.primaryColor,
                              ),
                              SizedBox(width: SpacingTokens.xs.w),
                              Expanded(
                                child: Text(
                                  S.lineDiscount,
                                  style: AppFonts.regular12(context)
                                      .copyWith(color: AppColor.primaryColor),
                                ),
                              ),
                              PriceLabel(
                                amount: line.discount,
                                prefix: '-',
                                style: AppFonts.regular12(context)
                                    .copyWith(color: AppColor.primaryColor),
                                iconSize: 11,
                                iconColor: AppColor.primaryColor,
                              ),
                            ],
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(),
          SizedBox(height: SpacingTokens.sm.h),
          if (order.deliveryFee > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(S.deliveryFee, style: AppFonts.regular14(context)),
                PriceLabel(
                  amount: order.deliveryFee,
                  style: AppFonts.medium14(context),
                  iconSize: 14,
                ),
              ],
            ),
            SizedBox(height: SpacingTokens.sm.h),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.total, style: AppFonts.semiBold16(context)),
              PriceLabel(
                amount: order.total,
                style: AppFonts.semiBold18(context)
                    .copyWith(color: AppColor.primaryColor),
                iconSize: 18,
                iconColor: AppColor.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.greyColor),
          ),
          SizedBox(height: 4.h),
          Text(value, style: AppFonts.medium14(context)),
        ],
      ),
    );
  }
}
