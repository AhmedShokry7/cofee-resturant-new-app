import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/shipping_address_section.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

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
        const ShippingAddressSection(),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        Text("Order List", style: AppFonts.semiBold16(context)),
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
            final subtotal = cart.total;
            final total = cubit.finalTotal(subtotal);
            final saved = subtotal - (total - AppConstant.deliveryFee);
            return Column(
              children: [
                _SummaryRow(label: "Subtotal", value: Formatters.price(subtotal)),
                SizedBox(height: SpacingTokens.xs.h),
                _SummaryRow(
                  label: "Delivery Fee",
                  value: Formatters.price(AppConstant.deliveryFee),
                ),
                if (saved > 0) ...[
                  SizedBox(height: SpacingTokens.xs.h),
                  _SummaryRow(
                    label: "Coupon discount",
                    value: "-${Formatters.price(saved)}",
                    highlight: true,
                  ),
                ],
                SizedBox(height: SpacingTokens.xs.h),
                _SummaryRow(
                  label: "Total",
                  value: Formatters.price(total),
                  highlight: true,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.big = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool big;

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
          style: (big
                  ? AppFonts.semiBold18(context)
                  : AppFonts.semiBold14(context))
              .copyWith(
                color: highlight
                    ? AppColor.primaryColor
                    : AppColor.blackColor,
              ),
        ),
      ],
    );
  }
}
