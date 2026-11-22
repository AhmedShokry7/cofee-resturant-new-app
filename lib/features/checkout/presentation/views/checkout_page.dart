import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/checkout_bottom_bar.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/checkout_page_body.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  static const routeName = "checkoutRoute";

  @override
  Widget build(BuildContext context) {
    final signedIn =
        SupabaseService.isReady &&
        SupabaseService.client.auth.currentUser != null;
    return Scaffold(
      appBar: AppBar(title: DesignText(S.checkout, page: 'checkout', label: 'checkout')),
      body: const CheckoutPageBody(),
      bottomNavigationBar: signedIn
          ? const CheckoutBottomBar()
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .pushNamed(AuthPage.routeName, arguments: routeName),
                  child: DesignText(S.signIn, page: 'checkout', label: 'signIn'),
                ),
              ),
            ),
    );
  }
}
