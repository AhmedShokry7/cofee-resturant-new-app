import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
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

    final orderId = checkout.state.lastOrder?.id ?? '';
    final selectedMethod = checkout.state.selectedPaymentMethod;
    final isOnline = selectedMethod?.isOnline ?? false;

    if (isOnline && orderId.isNotEmpty) {
      final publicKey = const String.fromEnvironment('TAP_PUBLIC_KEY');
      final sdkConfig = <String, dynamic>{};
      final result = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => CardPaymentPage(
            orderId: orderId,
            idempotencyKey: orderId,
            publicKey: publicKey,
            sdkConfiguration: sdkConfig,
          ),
        ),
      );
      if (!context.mounted) return;
      if (result != true) return;
    }

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
