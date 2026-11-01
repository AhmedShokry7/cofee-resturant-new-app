import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/shipping_addresses_page.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
            Text(S.shippingAddress, style: AppFonts.semiBold16(context)),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  AppIcons.location,
                  size: AppSpacing.xl,
                  color: AppColor.primaryColor,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address?.label ?? '—',
                        style: AppFonts.semiBold16(context),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        address?.details ?? '',
                        style: AppFonts.regular14(context)
                            .copyWith(color: AppColor.greyColor),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(ShippingAddressesPage.routeName),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSizes.px6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColor.borderColor),
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                    ),
                    child: Text(
                      S.change,
                      style: AppFonts.regular12(context)
                          .copyWith(color: AppColor.primaryColor),
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
