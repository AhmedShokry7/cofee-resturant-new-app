import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/branch/presentation/views/widgets/branch_selector.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/delivery_fulfillment_section.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/shipping_address_section.dart';
import 'package:new_coffee/shared/widgets/labeled_value_row.dart';

class CheckoutPageBody extends StatelessWidget {
  const CheckoutPageBody({super.key});

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
        Text(S.pickupBranch, style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: BranchSelector(),
        ),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        const DeliveryFulfillmentSection(),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        const ShippingAddressSection(),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        Text(S.orderList, style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        BlocBuilder<CartCubit, CartState>(
          builder: (context, state) {
            return Column(
              children: state.items
                  .map(
                    (item) => OrderItemCard(
                      product: item.product,
                      quantity: item.quantity,
                      note: item.note,
                      unitPrice: item.unitPrice,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        SizedBox(height: SpacingTokens.md.h),
        const _OrderSummary(),
      ],
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) {
        return BlocBuilder<CheckoutCubit, CheckoutState>(
          builder: (context, checkout) {
            final cubit = context.read<CheckoutCubit>();
            final summary = cubit.summary(cart.total);
            final subtotal = summary.subtotal;
            final total = summary.total;
            final saved = summary.discount;
            return Column(
              children: [
                LabeledValueRow(label: S.subtotal, priceValue: subtotal),
                SizedBox(height: SpacingTokens.xs.h),
                LabeledValueRow(
                  label: S.deliveryFee,
                  priceValue: summary.deliveryFee,
                ),
                if (saved > 0) ...[
                  SizedBox(height: SpacingTokens.xs.h),
                  LabeledValueRow(
                    label: S.couponDiscount,
                    priceValue: saved,
                    pricePrefix: '-',
                    emphasized: true,
                  ),
                ],
                SizedBox(height: SpacingTokens.xs.h),
                LabeledValueRow(
                  label: S.total,
                  priceValue: total,
                  emphasized: true,
                  big: true,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
