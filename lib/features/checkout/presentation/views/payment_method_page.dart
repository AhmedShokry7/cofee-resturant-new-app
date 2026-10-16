import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';

import 'package:new_coffee/features/checkout/presentation/views/widgets/payment_method_bottom_bar.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/payment_method_page_body.dart';

class PaymentMethodPage extends StatelessWidget {
  const PaymentMethodPage({super.key});

  static const routeName = "paymentMethodRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.paymentMethod)),
      body: const PaymentMethodPageBody(),
      bottomNavigationBar: const PaymentMethodBottomBar(),
    );
  }
}
