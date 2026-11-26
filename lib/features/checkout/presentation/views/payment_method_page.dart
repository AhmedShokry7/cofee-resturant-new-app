import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/locale/app_strings.dart';

import 'package:new_coffee/features/checkout/presentation/views/widgets/payment_method_bottom_bar.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/payment_method_page_body.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class PaymentMethodPage extends StatelessWidget {
  const PaymentMethodPage({super.key});

  static const routeName = "paymentMethodRoute";

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: DesignText(
            S.paymentMethod,
            page: 'payment_method',
            label: 'paymentMethod',
          ),
        ),
        body: const PaymentMethodPageBody(),
        bottomNavigationBar: const PaymentMethodBottomBar(),
      ),
    );
  }
}
