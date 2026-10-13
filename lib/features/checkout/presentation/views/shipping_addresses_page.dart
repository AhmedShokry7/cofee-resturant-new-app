import 'package:flutter/material.dart';

import 'package:new_coffee/features/checkout/presentation/views/widgets/shipping_addresses_bottom_bar.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/shipping_addresses_page_body.dart';

class ShippingAddressesPage extends StatelessWidget {
  const ShippingAddressesPage({super.key});

  static const routeName = "shippingAddressesRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shipping Address")),
      body: const ShippingAddressesPageBody(),
      bottomNavigationBar: const ShippingAddressesBottomBar(),
    );
  }
}
