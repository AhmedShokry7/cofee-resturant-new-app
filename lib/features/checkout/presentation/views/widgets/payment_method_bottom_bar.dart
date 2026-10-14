import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class PaymentMethodBottomBar extends StatelessWidget {
  const PaymentMethodBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SpacingTokens.lg.w),
      decoration: const BoxDecoration(
        color: AppColor.whiteColor,
        border: Border(top: BorderSide(color: AppColor.borderColor)),
      ),
      child: CustomBtn(
        text: "Confirm Payment",
        onPressed: () {
          final cart = context.read<CartCubit>().state;
          context.read<CheckoutCubit>().placeOrder(
            items: cart.items,
            total: cart.total,
          );
          context.read<LoyaltyCubit>().earnForOrder(cart.total);
          context.read<CartCubit>().clear();
          Navigator.of(context).pushNamedAndRemoveUntil(
            PaymentSuccessPage.routeName,
            (route) => route.isFirst,
          );
        },
      ),
    );
  }
}
