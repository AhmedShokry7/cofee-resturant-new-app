import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/features/checkout/data/model/order_model.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_state.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/payment/data/moyasar_checkout_config.dart';
import 'package:new_coffee/shared/widgets/primary_bottom_bar.dart';

class PaymentMethodBottomBar extends StatefulWidget {
  const PaymentMethodBottomBar({super.key});

  @override
  State<PaymentMethodBottomBar> createState() => _PaymentMethodBottomBarState();
}

class _PaymentMethodBottomBarState extends State<PaymentMethodBottomBar> {
  bool _confirming = false;

  Future<void> _confirm(BuildContext context) async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      await _runCheckout(context);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _runCheckout(BuildContext context) async {
    final cart = context.read<CartCubit>();
    final checkout = context.read<CheckoutCubit>();
    final loyalty = context.read<LoyaltyCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final selectedMethod = checkout.state.selectedPaymentMethod;
    final selectedCard = checkout.state.selectedSavedCard;
    final savedCard = selectedMethod?.isCardMethod == true &&
            selectedCard != null &&
            selectedCard.provider == 'moyasar'
        ? selectedCard
        : null;
    if (selectedMethod == null) {
      messenger.showSnackBar(SnackBar(content: Text(S.noPaymentMethods)));
      return;
    }
    if (!selectedMethod.isOnline && selectedMethod.code != 'cash') {
      messenger.showSnackBar(SnackBar(content: Text(S.noPaymentMethods)));
      return;
    }
    // An online card method cannot be treated like cash when the app was
    // built without Moyasar configuration.
    // Check before placing the order so a misconfigured build cannot create an
    // order that looks like a successful online checkout.
    if (selectedMethod.isOnline &&
        selectedMethod.isCardMethod &&
        !MoyasarCheckoutConfig.enabled) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'الدفع الإلكتروني غير مفعّل في هذه النسخة. أعد تشغيل التطبيق عبر tools/run_flutter.ps1 أو ابنِه عبر tools/build_apk.ps1.',
          ),
        ),
      );
      return;
    }
    if (selectedMethod.isOnline &&
        !const {
          'card',
          'mada',
          'stc_pay',
          'apple_pay',
          'samsung_pay',
        }.contains(selectedMethod.code)) {
      messenger.showSnackBar(SnackBar(content: Text(S.noPaymentMethods)));
      return;
    }

    final items = cart.state.items;
    final isOnline = selectedMethod.isOnline;
    final chargeCubit = context.read<CardPaymentCubit>();
    OrderModel? order;
    if (isOnline) {
      late final Map<String, dynamic> checkoutDraft;
      try {
        checkoutDraft = await checkout.createMoyasarCheckoutDraft(items);
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(S.paymentRetryLater)));
        return;
      }
      if (!context.mounted) return;

      // No order is inserted here. The payment screen finalizes the checkout
      // on the server only after Moyasar confirms a captured payment.
      if (savedCard != null) {
        chargeCubit.start(
          savedCardId: savedCard.id,
          checkoutDraft: checkoutDraft,
        );
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
      final paid = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => CardPaymentPage(
            paymentMethod: selectedMethod.code ?? 'card',
            checkoutDraft: checkoutDraft,
            amount: checkout.finalTotal(cart.state.total),
            savedCardId: savedCard?.id,
          ),
        ),
      );
      if (!context.mounted) return;
      if (paid != true) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              chargeCubit.state.errorMessageCopy ?? S.paymentNotCompleted,
            ),
          ),
        );
        return;
      }
      final verifiedOrder = chargeCubit.state.finalizedOrder;
      if (verifiedOrder == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(S.paymentVerificationFailed)),
        );
        return;
      }
      try {
        checkout.acceptVerifiedMoyasarOrder(order: verifiedOrder, items: items);
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(content: Text(S.paymentVerificationFailed)),
        );
        return;
      }
      order = checkout.state.lastOrder;
    } else {
      final placed = await checkout.placeOrder(items: items);
      if (!context.mounted) return;
      if (!placed) {
        final message = checkout.state.orderErrorCopy ?? S.orderFailed;
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      order = checkout.state.lastOrder;
      final warning = checkout.state.orderWarningCopy;
      if (warning != null && warning.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(warning)));
      }
    }

    // The attempt is over: the money was taken, or the order is a cash one the
    // kitchen already received. Only now may the idempotency key be retired, so
    // a payment that failed left the retap on the same unpaid order instead of
    // creating a second one.
    await checkout.settleOrderAttempt();
    await loyalty.earnForOrder(
      checkout.pointsBase(cart.state.total),
      serverPointsEarned: order?.pointsEarned,
    );
    navigator.pushNamedAndRemoveUntil(
      PaymentSuccessPage.routeName,
      (route) => route.isFirst,
      arguments: isOnline,
    );
    // Show the verified result before clearing the cart. Otherwise the old
    // payment page briefly reprices an empty cart and flashes an order error.
    cart.clear();
    await cart.flushServerSync();
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
          previous.selectedPaymentMethod != current.selectedPaymentMethod ||
          previous.deliveryBlocked != current.deliveryBlocked,
      builder: (context, state) => PrimaryBottomBar(
        text: S.confirmPayment,
        isLoading: _confirming || state.isPlacingOrder,
        enabled:
            !_confirming &&
            !state.isPlacingOrder &&
            !state.addressOutOfZone &&
            !state.isResolvingZone &&
            state.selectedPaymentMethod != null &&
            !state.deliveryBlocked &&
            !state.quoteLoading &&
            state.checkoutQuote != null,
        onPressed: () => _confirm(context),
      ),
    );
  }
}
