import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/order_model.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
              icon: AppIcons.receipt,
              title: S.noReceipt,
              subtitle: S.receiptHint,
            )
          : ListView(
              padding: AppLayout.pageBody,
              children: [
                _ReceiptCard(order: order),
                SizedBox(height: AppSpacing.lg),
                _InfoCard(
                  label: S.fulfillmentMethod,
                  value: order.isDelivery ? S.deliveryMethod : S.pickupMethod,
                ),
                if (order.isDelivery && order.deliveryZoneName != null) ...[
                  SizedBox(height: AppSpacing.md),
                  _InfoCard(
                    label: S.deliveryZone,
                    value: order.deliveryZoneName!,
                  ),
                ],
                if (order.isDelivery && order.deliveryAddress != null) ...[
                  SizedBox(height: AppSpacing.md),
                  _InfoCard(
                    label: S.shippingAddress,
                    value: order.deliveryAddress!,
                  ),
                ],
                SizedBox(height: AppSpacing.md),
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
    // The price of the items before the promotion, so the receipt adds up.
    final itemsTotal = order.items.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColor.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.receipt,
                size: AppSpacing.xl,
                color: AppColor.primaryColor,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  S.eReceipt,
                  style: AppFonts.semiBold18(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                order.id,
                style: AppFonts.medium14(context)
                    .copyWith(color: AppColor.greyColor),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            Formatters.date(order.date),
            style: AppFonts.regular14(context)
                .copyWith(color: AppColor.greyColor),
          ),
          SizedBox(height: AppSpacing.md),
          const Divider(),
          ...order.items.map(
            (item) => Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                            top: AppSpacing.xxs,
                            left: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.discount,
                                size: AppSpacing.md,
                                color: AppColor.primaryColor,
                              ),
                              SizedBox(width: AppSpacing.xs),
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
          SizedBox(height: AppSpacing.sm),
          if (order.productDiscount > 0) ...[
            // The price before the promotion and the promotion itself, so the
            // rows add up to the total the customer paid.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(S.subtotal, style: AppFonts.regular14(context)),
                PriceLabel(
                  amount: itemsTotal + order.productDiscount,
                  style: AppFonts.medium14(context),
                  iconSize: 14,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.productDiscount,
                  style: AppFonts.regular14(context)
                      .copyWith(color: AppColor.primaryColor),
                ),
                PriceLabel(
                  amount: order.productDiscount,
                  prefix: '-',
                  style: AppFonts.medium14(context)
                      .copyWith(color: AppColor.primaryColor),
                  iconSize: 14,
                  iconColor: AppColor.primaryColor,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
          ],
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
            SizedBox(height: AppSpacing.sm),
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
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
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
          SizedBox(height: AppSpacing.xs),
          Text(value, style: AppFonts.medium14(context)),
        ],
      ),
    );
  }
}
