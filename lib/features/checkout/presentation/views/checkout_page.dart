import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/checkout_bottom_bar.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/checkout_page_body.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  static const routeName = "checkoutRoute";

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  CheckoutCubit? _checkout;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkout ??= context.read<CheckoutCubit>();
  }

  @override
  void dispose() {
    _checkout?.clearSubscriptionOrder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn =
        SupabaseService.isReady &&
        SupabaseService.client.auth.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: DesignText(S.checkout, page: 'checkout', label: 'checkout'),
      ),
      body: const CheckoutPageBody(),
      bottomNavigationBar: signedIn
          ? const CheckoutBottomBar()
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: CustomFilledButton(
                  onPressed: () => Navigator.of(context).pushNamed(
                    AuthPage.routeName,
                    arguments: CheckoutPage.routeName,
                  ),
                  child: DesignText(
                    S.signIn,
                    page: 'checkout',
                    label: 'signIn',
                  ),
                ),
              ),
            ),
    );
  }
}
