import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/views/e_receipt_page.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({super.key});

  static const routeName = "paymentSuccessRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.payment)),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: AppDimensions.paymentSuccessMark,
                    width: AppDimensions.paymentSuccessMark,
                    decoration: BoxDecoration(
                      color: AppColor.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.checkmark,
                      size: AppSizes.px56,
                      color: AppColor.whiteColor,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl),
                  Text(
                    S.paymentSuccess,
                    textAlign: TextAlign.center,
                    style: AppFonts.semiBold24(context)
                        .copyWith(color: AppColor.secondryColor),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    S.thankYouPurchase,
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                  BlocBuilder<LoyaltyCubit, LoyaltyState>(
                    builder: (context, state) {
                      if (state.lastEarned <= 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          S.loyaltyPointsEarned(state.lastEarned),
                          textAlign: TextAlign.center,
                          style: AppFonts.medium14(context)
                              .copyWith(color: AppColor.primaryColor),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColor.whiteColor,
              border: Border(top: BorderSide(color: AppColor.borderColor)),
            ),
            child: Column(
              children: [
                CustomBtn(
                  text: S.goToMain,
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                ),
                SizedBox(height: AppSpacing.md),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushNamed(EReceiptPage.routeName),
                  child: Text(
                    S.viewEReceipt,
                    style: AppFonts.medium16(context)
                        .copyWith(color: AppColor.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
