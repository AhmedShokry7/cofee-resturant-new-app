import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/add_address_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/address_tile.dart';

class ShippingAddressesPageBody extends StatelessWidget {
  const ShippingAddressesPageBody({super.key});

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
            for (var index = 0; index < state.addresses.length; index++) ...[
              AddressTile(
                address: state.addresses[index],
                selected:
                    state.selectedAddress.id == state.addresses[index].id,
                onTap: () => context.read<CheckoutCubit>().selectAddress(
                  state.addresses[index],
                ),
              ),
              if (index != state.addresses.length - 1) const Divider(),
            ],
            SizedBox(height: SpacingTokens.xl.h),
            _AddAddressButton(
              onTap: () => Navigator.of(
                context,
              ).pushNamed(AddAddressPage.routeName),
            ),
          ],
        );
      },
    );
  }
}

class _AddAddressButton extends StatelessWidget {
  const _AddAddressButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColor.primaryColor),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          "+ Add new shipping address",
          style: AppFonts.medium12(
            context,
          ).copyWith(color: AppColor.primaryColor),
        ),
      ),
    );
  }
}

