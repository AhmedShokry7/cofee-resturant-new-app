import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/shipping_addresses_page.dart';

class ShippingAddressSection extends StatelessWidget {
  const ShippingAddressSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, state) {
        final address = state.selectedAddress;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Shipping Address", style: AppFonts.semiBold16(context)),
            SizedBox(height: SpacingTokens.md.h),
            Row(
              children: [
                Icon(
                  HugeIcons.strokeRoundedLocation01,
                  size: 24.w,
                  color: AppColor.primaryColor,
                ),
                SizedBox(width: SpacingTokens.md.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
Text(address?.label ?? '—', style: AppFonts.semiBold16(context)),
                      SizedBox(height: 4.h),
                      Text(
                        address?.details ?? '',
                        style: AppFonts.regular14(
                          context,
                        ).copyWith(color: AppColor.greyColor),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: SpacingTokens.sm.w),
                GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(ShippingAddressesPage.routeName),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: SpacingTokens.md.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColor.borderColor),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      "Change",
                      style: AppFonts.regular12(
                        context,
                      ).copyWith(color: AppColor.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

