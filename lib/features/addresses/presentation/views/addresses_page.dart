import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/addresses/presentation/manager/addresses/addresses_cubit.dart';
import 'package:new_coffee/features/addresses/presentation/views/address_form_page.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/address_tile.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Standalone address book reachable from Settings.
///
/// Reads and writes only through the shared `AddressRepository`; access control
/// stays in the owner-only RLS policies on the server.
class AddressesPage extends StatelessWidget {
  const AddressesPage({super.key});

  static const routeName = 'addressesRoute';

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(S.myAddresses)),
        body: const _AddressesView(),
      ),
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
    if (confirmed != true) return;
    // The answer goes to the state, and the listener above shows it: a delete
    // the server refused leaves the row on screen, which is the truth.
    await cubit.removeAddress(addressId);
  }

  void _openEditor(BuildContext context, [AddressModel? address]) =>
      Navigator.of(context)
          .pushNamed(AddressFormPage.routeName, arguments: address);

  @override
  Widget build(BuildContext context) {
    return BlocListener<AddressesCubit, AddressesState>(
      // A failed read already has its own inline state with a retry; only a
      // failed write needs a message over the list. The error is cleared right
      // after the snackbar is queued, so rebuilds cannot resurface it.
      listenWhen: (previous, current) =>
          current.error != null && !current.readFailed,
      listener: (context, state) {
        final message = state.errorCopy;
        if (message == null) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        context.read<AddressesCubit>().clearError();
      },
      child: BlocBuilder<AddressesCubit, AddressesState>(
        builder: (context, state) {
          if (state.isLoading && state.addresses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.readFailed) {
            // A failed read, not an empty book: the retry re-reads, because
            // telling the customer they have no addresses is the wrong answer
            // to a request that never arrived.
            return EmptyState(
              icon: AppIcons.location,
              title: S.couldNotLoadAddresses,
              actionLabel: S.retry,
              onAction: () => context.read<AddressesCubit>().load(),
            );
          }
          if (state.addresses.isEmpty) {
            return Padding(
              padding: AppLayout.pageBody,
              child: Column(
                children: [
                  Expanded(
                    child: EmptyState(
                      icon: AppIcons.location,
                      title: S.noAddresses,
                      subtitle: S.addressesHint,
                    ),
                  ),
                  _AddAddressButton(
                    onTap: () =>
                        Navigator.of(context)
                            .pushNamed(AddressFormPage.routeName),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: AppLayout.pageBody,
            children: [
              for (final address in state.addresses)
                AddressTile(
                  address: address,
                  selected: address.isDefault,
                  // The row opens the editor: this screen has no address to
                  // select, so a tap here means "change this one". No radio:
                  // it would promise a selection this page never makes.
                  showSelector: false,
                  onTap: () => _openEditor(context, address),
                  onSetDefault: () => context
                      .read<AddressesCubit>()
                      .setDefaultAddress(address.id),
                  onDelete: () =>
                      _confirmDelete(context, addressId: address.id),
                ),
              SizedBox(height: AppSpacing.xl),
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
    return CustomBtn(
      text: S.enterLocation,
      leadingIcon: Icon(AppIcons.add, color: AppColor.primaryColor),
      variant: BtnVariant.outlined,
      onPressed: onTap,
    );
  }
}
