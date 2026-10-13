import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_method_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class CheckoutBottomBar extends StatelessWidget {
  const CheckoutBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SpacingTokens.lg.w),
      decoration: const BoxDecoration(
        color: AppColor.whiteColor,
        border: Border(top: BorderSide(color: AppColor.borderColor)),
      ),
      child: CustomBtn(
        text: "Continue to Payment",
        onPressed: () =>
            Navigator.of(context).pushNamed(PaymentMethodPage.routeName),
      ),
    );
  }
}
