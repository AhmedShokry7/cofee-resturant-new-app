import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';

import 'package:new_coffee/features/checkout/presentation/views/widgets/add_address_page_body.dart';

class AddAddressPage extends StatelessWidget {
  const AddAddressPage({super.key});

  static const routeName = "addAddressRoute";

  @override
  Widget build(BuildContext context) {
    final address = ModalRoute.of(context)?.settings.arguments;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          address is AddressModel ? S.editAddress : S.enterLocation,
        ),
      ),
      body: AddAddressPageBody(
        address: address is AddressModel ? address : null,
      ),
    );
  }
}
