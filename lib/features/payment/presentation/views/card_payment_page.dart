import 'dart:async';

import 'package:card_flutter/card_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';
import 'package:new_coffee/features/payment/data/tap_checkout_config.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_state.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/shared/widgets/primary_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The hosted card form, the 3DS redirect it opens, and what happens when the
/// customer comes back from it.
///
/// The page is the route entry only: tokenizing, charging and verifying all
/// belong to [CardPaymentCubit].
class CardPaymentPage extends StatefulWidget {
  const CardPaymentPage({
    super.key,
    this.orderId = '',
    this.subscriptionId,
    this.savedCardId,
    this.amount = 0,
    this.currency = TapCheckoutConfig.defaultCurrency,
  });

  /// The server id of the order being paid (a uuid), never the order number.
  final String orderId;
  final String? subscriptionId;

  /// Opens the form for a subscription the customer just started or renewed.
  ///
  /// [amount] has to be the price of the plan being paid for, because the form
  /// shows the figure the server is going to charge.
  static void pushForSubscription(
    BuildContext context, {
    required String subscriptionId,
    required double amount,
    required String currency,
  }) {
    final repository = context.read<TapPaymentRepository>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => CardPaymentCubit(repository: repository),
          child: CardPaymentPage(
            subscriptionId: subscriptionId,
            amount: amount,
            currency: currency,
          ),
        ),
      ),
    );
  }

  /// When set, the page charges this saved card instead of showing the hosted
  /// form. The bottom bar sets it after placing the order.
  final String? savedCardId;

  /// The amount the customer is charged, in [currency].
  ///
  /// The card form shows this figure, so it has to be the real one: the server
  /// charges `orders.grand_total` (or the plan price for a subscription), and a
  /// form that shows anything else is a lie.
  final double amount;
  final String currency;

  @override
  State<CardPaymentPage> createState() => _CardPaymentPageState();
}

class _CardPaymentPageState extends State<CardPaymentPage>
    with WidgetsBindingObserver {
  /// True once the 3DS page was opened. The charge is only verified when the
  /// app comes back from it, so this is what tells the resume handler that
  /// there is something to verify.
  bool _redirectLaunched = false;

  /// The order or subscription the form is opened for.
  String get _targetId => widget.subscriptionId ?? widget.orderId;

  /// Whether a stored card pays this order, so the card form is not shown.
  bool get _chargesSavedCard {
    final savedCardId = widget.savedCardId;
    return savedCardId != null && savedCardId.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cubit = context.read<CardPaymentCubit>();
    // The saved-card flow creates the charge before this page is opened. That
    // charge belongs to this order, so it is kept: resetting it would lose the
    // charge id and the redirect URL the customer still has to follow.
    final alreadyCharged =
        cubit.state.status == CardPaymentStatus.chargeCreated &&
        (cubit.state.chargeId ?? '').isNotEmpty;
    cubit.start(
      orderId: widget.orderId.isEmpty ? null : widget.orderId,
      subscriptionId: widget.subscriptionId,
      savedCardId: widget.savedCardId,
      reset: !alreadyCharged,
    );
    if (alreadyCharged) {
      // The charge was created before this page was opened (the saved-card
      // flow), so its redirect URL is never announced by a state change: it
      // has to be followed from here.
      final url = cubit.state.transactionUrl;
      if (url != null && url.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _launch3DS(url));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The customer comes back from the bank's page here. That is the only
    // moment the charge can be verified: the redirect happens outside the
    // app, so nothing inside it ever learns the outcome.
    if (state == AppLifecycleState.resumed) {
      unawaited(_verifyAfterRedirect());
    }
  }

  Future<void> _launch3DS(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    _redirectLaunched = true;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Verifies the charge after the customer came back from the bank.
  ///
  /// A verified charge ends the payment: the order is paid, the cart is
  /// emptied and the customer is shown the confirmation. An unverified one
  /// leaves the order unpaid and the cart intact, so nothing is lost.
  Future<void> _verifyAfterRedirect() async {
    if (!mounted || !_redirectLaunched) return;
    final cubit = context.read<CardPaymentCubit>();
    if ((cubit.state.chargeId ?? '').isEmpty) return;
    if (cubit.state.status == CardPaymentStatus.paymentSucceeded) {
      _finish();
      return;
    }
    final outcome = await cubit.verifyCharge();
    if (!mounted) return;
    switch (outcome) {
      case PaymentOutcome.succeeded:
        _finish();
      case PaymentOutcome.pending:
        _showMessage(S.paymentProcessing);
      case PaymentOutcome.failed:
        _showMessage(cubit.state.errorMessageCopy ?? S.paymentFailed);
      case null:
        break;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Leaves the payment screen.
  ///
  /// A subscription goes to its own details page. An order returns `true` to
  /// the checkout, which then empties the cart and awards the loyalty points.
  void _finish() {
    if (!mounted) return;
    final subscriptionId = widget.subscriptionId;
    if (subscriptionId != null && subscriptionId.isNotEmpty) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        SubscriptionDetailsPage.routeName,
        (route) => route.isFirst,
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<CardPaymentCubit>(),
      child: _CardPaymentView(
        sdkConfiguration: TapCheckoutConfig.payload(
          targetId: _targetId,
          amount: widget.amount,
          currency: widget.currency,
        ),
        chargesSavedCard: _chargesSavedCard,
        on3DSLaunch: _launch3DS,
      ),
    );
  }
}

class _CardPaymentView extends StatelessWidget {
  const _CardPaymentView({
    required this.sdkConfiguration,
    required this.chargesSavedCard,
    required this.on3DSLaunch,
  });

  final Map<String, dynamic> sdkConfiguration;
  final Function(String) on3DSLaunch;

  /// A stored card is charged without the card form: there is nothing for the
  /// customer to type.
  final bool chargesSavedCard;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CardPaymentCubit, CardPaymentState>(
      listener: (context, state) {
        if (state.status == CardPaymentStatus.chargeCreated) {
          final url = state.transactionUrl;
          if (url != null && url.isNotEmpty) on3DSLaunch(url);
        }
      },
      builder: (context, state) {
        final cubit = context.read<CardPaymentCubit>();
        return Scaffold(
          appBar: AppBar(title: Text(S.payment)),
          body: Column(
            children: [
              Expanded(
                child: chargesSavedCard
                    ? _SavedCardPaymentNotice(state: state)
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: TapCardViewWidget(
                          sdkConfiguration: sdkConfiguration,
                          generateToken:
                              state.status == CardPaymentStatus.tokenizing,
                          onValidInput: (value) => cubit.onCardValidInput(
                            value?.toLowerCase() == 'true',
                          ),
                          onSuccess: cubit.onHostedFormResult,
                          onError: (_) => cubit.onHostedFormError(),
                          // The SDK calls these two through a force unwrap, so
                          // they must not be null even though nothing uses them.
                          onReady: () {},
                          onFocus: () {},
                          showLoading: true,
                        ),
                      ),
              ),
              if (state.errorMessage != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    state.errorMessageCopy!,
                    style: TextStyle(color: AppColor.errorColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!chargesSavedCard)
                PrimaryBottomBar(
                  text: S.confirmPayment,
                  isLoading: state.isBusy,
                  onPressed: state.canSubmit ? cubit.requestCardToken : () {},
                ),
            ],
          ),
        );
      },
    );
  }
}

/// What the customer sees while a stored card is being charged.
class _SavedCardPaymentNotice extends StatelessWidget {
  const _SavedCardPaymentNotice({required this.state});

  final CardPaymentState state;

  @override
  Widget build(BuildContext context) {
    final waiting =
        state.isBusy ||
        state.status == CardPaymentStatus.chargeCreated ||
        state.status == CardPaymentStatus.paymentPending;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (waiting)
              const CircularProgressIndicator()
            else
              Icon(
                AppIcons.creditCard,
                size: AppSpacing.xxxl,
                color: AppColor.primaryColor,
              ),
            SizedBox(height: AppSpacing.md),
            Text(
              waiting ? S.paymentProcessing : S.payment,
              style: TextStyle(color: AppColor.greyColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
