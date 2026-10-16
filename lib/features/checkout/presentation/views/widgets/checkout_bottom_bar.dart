import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_method_page.dart';
import 'package:new_coffee/shared/widgets/primary_bottom_bar.dart';

class CheckoutBottomBar extends StatelessWidget {
  const CheckoutBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryBottomBar(
      text: S.continueToPayment,
      onPressed: () =>
          Navigator.of(context).pushNamed(PaymentMethodPage.routeName),
    );
  }
}
