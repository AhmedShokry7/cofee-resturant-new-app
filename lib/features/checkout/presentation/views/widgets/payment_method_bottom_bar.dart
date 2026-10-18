import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_state.dart';
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

    final placed = await checkout.placeOrder(
      items: items,
      savedCardId: checkout.state.selectedSavedCard?.id,
    );
    if (!context.mounted) return;

    if (!placed) {
      final message = checkout.state.orderError ?? S.orderFailed;
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final orderId = checkout.state.lastOrder?.id ?? '';
    final selectedMethod = checkout.state.selectedPaymentMethod;
    final isOnline = selectedMethod?.isOnline ?? false;
    final savedCard = checkout.state.selectedSavedCard;

    // A saved card pays without the hosted form: the server charges it
    // directly, so the customer is never asked for a number they already gave.
    if (isOnline && savedCard != null && orderId.isNotEmpty) {
      final chargeCubit = context.read<CardPaymentCubit>();
      chargeCubit.start(orderId: orderId, savedCardId: savedCard.id);
      await chargeCubit.createCharge();
      if (!context.mounted) return;
      final chargeResult = chargeCubit.state;
      if (chargeResult.status == CardPaymentStatus.chargeCreated &&
          (chargeResult.transactionUrl ?? '').isNotEmpty) {
        final launched = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => CardPaymentPage(
              orderId: orderId,
              idempotencyKey: orderId,
              publicKey: const String.fromEnvironment('TAP_PUBLIC_KEY'),
              sdkConfiguration: <String, dynamic>{},
            ),
          ),
        );
        if (!context.mounted) return;
        if (launched != true) return;
      } else if (chargeResult.status == CardPaymentStatus.paymentFailed) {
        messenger.showSnackBar(
          SnackBar(content: Text(chargeResult.errorMessage ?? S.orderFailed)),
        );
        return;
      }
    } else if (isOnline && orderId.isNotEmpty) {
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
