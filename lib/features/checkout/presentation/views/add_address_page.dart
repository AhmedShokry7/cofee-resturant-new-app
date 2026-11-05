import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/addresses/presentation/views/widgets/address_form_body.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';

/// The address editor reached from checkout.
///
/// It writes through [CheckoutCubit] rather than the address book cubit,
/// because picking a delivery address also decides the zone and the fee the
/// order is quoted with.
class AddAddressPage extends StatelessWidget {
  const AddAddressPage({super.key});

  static const routeName = 'addAddressRoute';

  @override
  Widget build(BuildContext context) {
    final argument = ModalRoute.of(context)?.settings.arguments;
    final existing = argument is AddressModel ? argument : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? S.enterLocation : S.editAddress),
      ),
      body: AddressFormBody(
        address: existing,
        onSave: (draft) async {
          final cubit = context.read<CheckoutCubit>();
          // The editor waits for this answer, so a write the server refused
          // keeps the draft on screen instead of returning to a checkout that
          // never got the address.
          return draft.id.isEmpty
              ? cubit.addAddress(draft)
              : cubit.updateAddress(draft);
        },
      ),
    );
  }
}
