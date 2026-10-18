import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/addresses/presentation/manager/addresses/addresses_cubit.dart';
import 'package:new_coffee/features/addresses/presentation/views/address_form_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/address_tile.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

/// Standalone address book reachable from Settings.
///
/// Reads and writes only through the shared `AddressRepository`; access control
/// stays in the owner-only RLS policies on the server.
class AddressesPage extends StatelessWidget {
  const AddressesPage({super.key});

  static const routeName = 'addressesRoute';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.myAddresses)),
      body: const _AddressesView(),
    );
  }
}

class _AddressesView extends StatelessWidget {
  const _AddressesView();

  Future<void> _confirmDelete(
    BuildContext context, {
    required String addressId,
  }) async {
    final cubit = context.read<AddressesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.deleteAddress),
        content: Text(S.deleteAddressConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await cubit.removeAddress(addressId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AddressesCubit, AddressesState>(
      // Only failures on a non-empty list need a snackbar: the empty-list
      // case already shows an inline error with a retry button. The error is
      // cleared right after the snackbar is queued, so rebuilds cannot
      // resurface the same message.
      listenWhen: (previous, current) =>
          current.error != null && current.addresses.isNotEmpty,
      listener: (context, state) {
        final message = state.error;
        if (message == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        context.read<AddressesCubit>().clearError();
      },
      child: BlocBuilder<AddressesCubit, AddressesState>(
        builder: (context, state) {
        if (state.isLoading && state.addresses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null && state.addresses.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(SpacingTokens.xl.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmptyState(
                    icon: HugeIcons.strokeRoundedLocation01,
                    title: S.myAddresses,
                  ),
                  SizedBox(height: SpacingTokens.sm.h),
                  Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(
                      context,
                    ).copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: SpacingTokens.md.h),
                  TextButton(
                    onPressed: () => context.read<AddressesCubit>().load(),
                    child: Text(S.retry),
                  ),
                ],
              ),
            ),
          );
        }
        if (state.addresses.isEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.lg.w,
            ),
            child: Column(
              children: [
                Expanded(
                  child: EmptyState(
                    icon: HugeIcons.strokeRoundedLocation01,
                    title: S.noAddresses,
                    subtitle: S.addressesHint,
                  ),
                ),
                _AddAddressButton(
                  onTap: () =>
                      Navigator.of(context).pushNamed(
                        AddressFormPage.routeName,
                      ),
                ),
              ],
            ),
          );
        }
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
                selected: state.addresses[index].isDefault,
                onTap: () => context
                    .read<AddressesCubit>()
                    .setDefaultAddress(state.addresses[index].id),
                onSetDefault: () => context
                    .read<AddressesCubit>()
                    .setDefaultAddress(state.addresses[index].id),
                onEdit: () => Navigator.of(context).pushNamed(
                  AddressFormPage.routeName,
                  arguments: state.addresses[index],
                ),
                onDelete: () => _confirmDelete(
                  context,
                  addressId: state.addresses[index].id,
                ),
              ),
              if (index != state.addresses.length - 1) const Divider(),
            ],
            SizedBox(height: SpacingTokens.xl.h),
            _AddAddressButton(
              onTap: () =>
                  Navigator.of(context).pushNamed(AddressFormPage.routeName),
            ),
          ],
          );
        },
      ),
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
          '+ ${S.enterLocation}',
          style: AppFonts.medium12(context).copyWith(
            color: AppColor.primaryColor,
          ),
        ),
      ),
    );
  }
}
