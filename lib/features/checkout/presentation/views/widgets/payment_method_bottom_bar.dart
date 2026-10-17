import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/shared/widgets/primary_bottom_bar.dart';

class PaymentMethodBottomBar extends StatelessWidget {
  const PaymentMethodBottomBar({super.key});

  Future<void> _confirm(BuildContext context) async {
    final cart = context.read<CartCubit>();
    final checkout = context.read<CheckoutCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final items = cart.state.items;
    final total = checkout.finalTotal(cart.state.total);

    final placed = await checkout.placeOrder(items: items);
    if (!context.mounted) return;

    if (!placed) {
      final message = checkout.state.orderError ?? S.orderFailed;
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    // Only after the server persisted the order: award the local points view
    // and clear the device cart. Clearing earlier would lose the cart if the
    // placement had failed.
    context.read<LoyaltyCubit>().earnForOrder(total);
    cart.clear();
    navigator.pushNamedAndRemoveUntil(
      PaymentSuccessPage.routeName,
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) =>
          previous.isPlacingOrder != current.isPlacingOrder,
      builder: (context, state) => PrimaryBottomBar(
        text: S.confirmPayment,
        isLoading: state.isPlacingOrder,
        onPressed: () => _confirm(context),
      ),
    );
  }
}
