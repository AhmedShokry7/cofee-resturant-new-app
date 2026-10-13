import 'package:flutter/material.dart';

import 'package:new_coffee/features/checkout/presentation/views/widgets/checkout_bottom_bar.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/checkout_page_body.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  static const routeName = "checkoutRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Checkout")),
      body: const CheckoutPageBody(),
      bottomNavigationBar: const CheckoutBottomBar(),
    );
  }
}
