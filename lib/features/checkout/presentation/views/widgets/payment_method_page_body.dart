import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/add_card_tile.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/payment_option_tile.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

class PaymentMethodPageBody extends StatelessWidget {
  const PaymentMethodPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, state) {
        return ListView(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.lg.w,
            SpacingTokens.md.h,
            SpacingTokens.lg.w,
            SpacingTokens.lg.w,
          ),
          children: [
            const _PayableTotal(),
            SizedBox(height: SpacingTokens.lg.h),
            Text("Credit & Debit Card", style: AppFonts.semiBold16(context)),
            SizedBox(height: SpacingTokens.md.h),
            AddCardTile(
              onTap: () =>
                  Navigator.of(context).pushNamed(AddCardPage.routeName),
            ),
            SizedBox(height: SpacingTokens.xl.h),
            Text("More Payment Options", style: AppFonts.semiBold16(context)),
            SizedBox(height: SpacingTokens.md.h),
            ...state.paymentMethods.map(
              (method) => PaymentOptionTile(
                method: method,
                selected: state.selectedPaymentMethod.id == method.id,
                onTap: () =>
                    context.read<CheckoutCubit>().selectPaymentMethod(method),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PayableTotal extends StatelessWidget {
  const _PayableTotal();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) {
        final checkout = context.watch<CheckoutCubit>();
        return Container(
          padding: EdgeInsets.all(SpacingTokens.md.w),
          decoration: BoxDecoration(
            color: AppColor.lightGreyColor,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total to pay",
                style: AppFonts.regular14(
                  context,
                ).copyWith(color: AppColor.greyColor),
              ),
              Text(
                Formatters.price(checkout.finalTotal(cart.total)),
                style: AppFonts.semiBold18(
                  context,
                ).copyWith(color: AppColor.primaryColor),
              ),
            ],
          ),
        );
      },
    );
  }
}
