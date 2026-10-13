import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/add_card_tile.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/payment_option_tile.dart';

class PaymentMethodPageBody extends StatelessWidget {
  const PaymentMethodPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, state) {
        return ListView(
          padding: EdgeInsets.all(SpacingTokens.lg.w),
          children: [
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
