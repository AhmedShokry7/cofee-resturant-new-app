import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/views/e_receipt_page.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

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
                    height: 124.w,
                    width: 124.w,
                    decoration: BoxDecoration(
                      color: AppColor.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      HugeIcons.strokeRoundedTick02,
                      size: 56.w,
                      color: AppColor.whiteColor,
                    ),
                  ),
                  SizedBox(height: SpacingTokens.xl.h),
                  Text(
                    S.paymentSuccess,
                    textAlign: TextAlign.center,
                    style: AppFonts.semiBold24(context)
                        .copyWith(color: AppColor.secondryColor),
                  ),
                  SizedBox(height: SpacingTokens.sm.h),
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
                        padding: EdgeInsets.only(top: SpacingTokens.sm.h),
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
            padding: EdgeInsets.all(SpacingTokens.lg.w),
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
                SizedBox(height: SpacingTokens.md.h),
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
