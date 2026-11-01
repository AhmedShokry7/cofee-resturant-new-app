import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/addresses/presentation/manager/addresses/addresses_cubit.dart';
import 'package:new_coffee/features/addresses/presentation/views/widgets/address_form_body.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';

/// Add or edit one saved address.
///
/// Writes through [AddressesCubit] so the repository — and behind it the
/// owner-only RLS policies — stays the only path to the data.
class AddressFormPage extends StatelessWidget {
  const AddressFormPage({super.key});

  static const routeName = 'addressFormRoute';

  @override
  Widget build(BuildContext context) {
    final argument = ModalRoute.of(context)?.settings.arguments;
    final existing = argument is AddressModel ? argument : null;
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(
          title: Text(existing == null ? S.enterLocation : S.editAddress),
        ),
        body: AddressFormBody(
          address: existing,
          onSave: (draft) {
            final cubit = context.read<AddressesCubit>();
            // An empty id means the server has never seen this address, so it
            // is the one that assigns it.
            if (draft.id.isEmpty) {
              cubit.addAddress(
                label: draft.label,
                details: draft.details,
                latitude: draft.latitude,
                longitude: draft.longitude,
              );
            } else {
              cubit.updateAddress(draft);
            }
          },
        ),
      ),
    );
  }
}
