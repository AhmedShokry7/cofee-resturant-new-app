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
    final loyalty = context.read<LoyaltyCubit>();
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
      final message = checkout.state.orderErrorCopy ?? S.orderFailed;
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final order = checkout.state.lastOrder;
    // The server id of the order, never the number the customer reads. The
    // payment functions look the order up by its uuid.
    final orderId = order?.orderId ?? '';
    final warning = checkout.state.orderWarningCopy;
    if (warning != null && warning.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(warning)));
    }
    final selectedMethod = checkout.state.selectedPaymentMethod;
    final isOnline = selectedMethod?.isOnline ?? false;
    // A stored card can only pay a card method. Apple Pay and cash must never
    // be settled with the card the customer saved earlier.
    final savedCard = selectedMethod?.isCardMethod == true
        ? checkout.state.selectedSavedCard
        : null;

    if (isOnline && orderId.isNotEmpty) {
      final chargeCubit = context.read<CardPaymentCubit>();
      if (savedCard != null) {
        // A saved card pays without the hosted form: the server charges it
        // directly, so the customer is never asked for a number they already
        // gave.
        chargeCubit.start(orderId: orderId, savedCardId: savedCard.id);
        await chargeCubit.chargeSavedCard();
        if (!context.mounted) return;
        if (chargeCubit.state.status != CardPaymentStatus.chargeCreated) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                chargeCubit.state.errorMessageCopy ?? S.paymentRetryLater,
              ),
            ),
          );
          return;
        }
      }

      // The page verifies the charge when the customer comes back from the
      // bank and only returns true when the money was really taken.
      final paid = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => CardPaymentPage(
            orderId: orderId,
            amount: order?.total ?? total,
            savedCardId: savedCard?.id,
          ),
        ),
      );
      if (!context.mounted) return;
      if (paid != true) {
        // The charge was not completed. The order stays unpaid and the cart
        // stays intact, so nothing is lost and the customer can try again.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              chargeCubit.state.errorMessageCopy ?? S.paymentNotCompleted,
            ),
          ),
        );
        return;
      }
    }

    // The attempt is over: the money was taken, or the order is a cash one the
    // kitchen already received. Only now may the idempotency key be retired, so
    // a payment that failed left the retap on the same unpaid order instead of
    // creating a second one.
    await checkout.settleOrderAttempt();
    await loyalty.earnForOrder(total, serverPointsEarned: order?.pointsEarned);
    cart.clear();
    await cart.flushServerSync();
    navigator.pushNamedAndRemoveUntil(
      PaymentSuccessPage.routeName,
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) =>
          previous.isPlacingOrder != current.isPlacingOrder ||
          previous.checkoutQuote != current.checkoutQuote ||
          previous.quoteLoading != current.quoteLoading ||
          previous.addressOutOfZone != current.addressOutOfZone ||
          previous.isResolvingZone != current.isResolvingZone ||
          previous.deliveryBlocked != current.deliveryBlocked,
      builder: (context, state) => PrimaryBottomBar(
        text: S.confirmPayment,
        isLoading: state.isPlacingOrder,
        enabled:
            !state.isPlacingOrder &&
            !state.addressOutOfZone &&
            !state.isResolvingZone &&
            !state.deliveryBlocked &&
            !state.quoteLoading &&
            state.checkoutQuote != null,
        onPressed: () => _confirm(context),
      ),
    );
  }
}
