import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/add_address_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/address_tile.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class ShippingAddressesPageBody extends StatelessWidget {
  const ShippingAddressesPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    // A failed save, delete or default change is recorded in
    // `CheckoutState.error`; without this listener the shopper would see the
    // tap do nothing. The message is cleared once shown so an unrelated
    // rebuild cannot repeat it.
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listenWhen: (previous, current) =>
          current.error != null && previous.error != current.error,
      listener: (context, state) {
        if (state.error == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorCopy ?? S.addressSaveFailed)),
        );
        context.read<CheckoutCubit>().clearError();
      },
      builder: (context, state) {
        return ListView(
          padding: AppLayout.pageBody,
          children: [
            for (final address in state.addresses)
              AddressTile(
                address: address,
                selected: state.selectedAddress?.id == address.id,
                onTap: () =>
                    context.read<CheckoutCubit>().selectAddress(address),
                onSetDefault: () =>
                    context.read<CheckoutCubit>().setDefaultAddress(address.id),
                onEdit: () => Navigator.of(context)
                    .pushNamed(AddAddressPage.routeName, arguments: address),
                onDelete: () =>
                    context.read<CheckoutCubit>().removeAddress(address.id),
              ),
            SizedBox(height: AppSpacing.xl),
            _AddAddressButton(
              onTap: () =>
                  Navigator.of(context).pushNamed(AddAddressPage.routeName),
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
        height: AppDimensions.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColor.primaryColor),
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Text(
          S.addNewShippingAddress,
          style: AppFonts.medium12(context)
              .copyWith(color: AppColor.primaryColor),
        ),
      ),
    );
  }
}
