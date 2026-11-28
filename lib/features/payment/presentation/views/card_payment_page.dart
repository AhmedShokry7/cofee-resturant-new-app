import 'dart:async';

import 'package:moyasar/moyasar.dart';
import 'package:material_ui/material_ui.dart';
// Moyasar 3.x still uses legacy Material fields; keep matching ancestors.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as sdk_material;
import 'package:flutter_localizations/flutter_localizations.dart'
    as sdk_localizations;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/payment/data/moyasar_checkout_config.dart';
import 'package:new_coffee/features/payment/data/repositories/payment_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_state.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

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
    this.checkoutDraft,
    this.savedCardId,
    this.amount = 0,
    this.currency = 'SAR',
    this.paymentMethod = 'card',
  });

  /// The server id of the order being paid (a uuid), never the order number.
  final String orderId;
  final String? subscriptionId;
  final Map<String, dynamic>? checkoutDraft;

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
    final repository = context.read<PaymentRepository>();
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
  final String paymentMethod;

  @override
  State<CardPaymentPage> createState() => _CardPaymentPageState();
}

class _CardPaymentPageState extends State<CardPaymentPage>
    with WidgetsBindingObserver {
  /// True once the 3DS page was opened. The charge is only verified when the
  /// app comes back from it, so this is what tells the resume handler that
  /// there is something to verify.
  bool _redirectLaunched = false;
  bool _saveCardForFuture = false;
  bool _finished = false;

  /// The order or subscription the form is opened for.

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
    // Only preserve a pre-created saved-card charge when it belongs to this
    // exact checkout. This cubit is app-wide; a previous order can otherwise
    // leave a stale successful charge here and make a new payment look paid
    // before the customer enters a card.
    final alreadyCharged =
        _chargesSavedCard &&
        cubit.hasChargeCreatedFor(
          orderId: widget.orderId.isEmpty ? null : widget.orderId,
          subscriptionId: widget.subscriptionId,
          savedCardId: widget.savedCardId,
          checkoutKey: widget.checkoutDraft?['idempotency_key']?.toString(),
        );
    cubit.start(
      orderId: widget.orderId.isEmpty ? null : widget.orderId,
      subscriptionId: widget.subscriptionId,
      savedCardId: widget.savedCardId,
      checkoutDraft: widget.checkoutDraft,
      reset: !alreadyCharged,
    );
    if (MoyasarCheckoutConfig.enabled && !alreadyCharged) {
      unawaited(cubit.prepareMoyasarPayment());
    }
    if (alreadyCharged) {
      // The charge was created before this page was opened (the saved-card
      // flow), so its redirect URL is never announced by a state change: it
      // has to be followed from here.
      final url = cubit.state.transactionUrl;
      if (url != null && url.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _launch3DS(url));
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_verifySavedCardAfterCreate());
        });
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
        if (_saveCardForFuture) {
          unawaited(context.read<SavedCardsCubit>().load());
        }
        _finish();
      case PaymentOutcome.pending:
        _showMessage(S.paymentProcessing);
      case PaymentOutcome.failed:
        _showMessage(cubit.state.errorMessageCopy ?? S.paymentFailed);
      case null:
        break;
    }
  }

  Future<void> _verifySavedCardAfterCreate() async {
    if (!mounted) return;
    final outcome = await context.read<CardPaymentCubit>().verifyCharge();
    if (!mounted) return;
    switch (outcome) {
      case PaymentOutcome.succeeded:
        _finish();
      case PaymentOutcome.pending:
        _showMessage(S.paymentProcessing);
      case PaymentOutcome.failed:
        _showMessage(
          context.read<CardPaymentCubit>().state.errorMessageCopy ??
              S.paymentFailed,
        );
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
    if (!mounted ||
        _finished ||
        context.read<CardPaymentCubit>().state.status !=
            CardPaymentStatus.paymentSucceeded) {
      return;
    }
    _finished = true;
    if (_saveCardForFuture &&
        context.read<CardPaymentCubit>().state.savedCardStatus != 'saved') {
      _showMessage(S.paymentSucceededCardNotSaved);
    }
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
        paymentMethod: widget.paymentMethod,
        chargesSavedCard: _chargesSavedCard,
        saveCard: _saveCardForFuture,
        onSaveCardChanged: (value) =>
            setState(() => _saveCardForFuture = value),
        on3DSLaunch: _launch3DS,
        onMoyasarResult: _handleMoyasarResult,
        onRetryVerification: _verifySavedCardAfterCreate,
      ),
    );
  }

  Future<void> _handleMoyasarResult(dynamic result) async {
    if (!mounted) return;
    final outcome = await context.read<CardPaymentCubit>().verifyCharge();
    if (!mounted) return;
    switch (outcome) {
      case PaymentOutcome.succeeded:
        if (_saveCardForFuture) {
          unawaited(context.read<SavedCardsCubit>().load());
        }
        _finish();
      case PaymentOutcome.pending:
        _showMessage(S.paymentProcessing);
      case PaymentOutcome.failed:
        _showMessage(
          context.read<CardPaymentCubit>().state.errorMessageCopy ??
              S.paymentFailed,
        );
      case null:
        if (result is PaymentResponse &&
            result.status == PaymentStatus.initiated) {
          _showMessage(S.paymentProcessing);
        }
    }
  }
}

class _CardPaymentView extends StatelessWidget {
  const _CardPaymentView({
    required this.chargesSavedCard,
    required this.saveCard,
    required this.onSaveCardChanged,
    required this.on3DSLaunch,
    required this.onMoyasarResult,
    required this.paymentMethod,
    required this.onRetryVerification,
  });

  final String paymentMethod;
  final VoidCallback onRetryVerification;
  final Function(String) on3DSLaunch;
  final Function(dynamic) onMoyasarResult;

  /// A stored card is charged without the card form: there is nothing for the
  /// customer to type.
  final bool chargesSavedCard;
  final bool saveCard;
  final ValueChanged<bool> onSaveCardChanged;

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
        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(),
            title: Text(S.payment),
          ),
          body: Column(
            children: [
              if (!chargesSavedCard &&
                  MoyasarCheckoutConfig.enabled &&
                  (paymentMethod == 'card' || paymentMethod == 'mada'))
                CheckboxListTile(
                  value: saveCard,
                  onChanged: state.isBusy
                      ? null
                      : (value) => onSaveCardChanged(value ?? false),
                  title: Text(S.saveCardForFuture),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                ),
              Expanded(
                child: chargesSavedCard
                    ? _SavedCardPaymentNotice(state: state)
                    : MoyasarCheckoutConfig.enabled
                    ? _buildMoyasarForm(
                        context,
                        state,
                        onMoyasarResult,
                        saveCard,
                      )
                    : const Center(
                        child: Text(
                          'الدفع الإلكتروني غير مهيأ. أعد تشغيل التطبيق بإعدادات Moyasar.',
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
              if ((state.chargeId ?? '').isNotEmpty &&
                  (state.status == CardPaymentStatus.paymentPending ||
                      state.status == CardPaymentStatus.paymentFailed))
                TextButton(
                  onPressed: onRetryVerification,
                  child: Text(S.retry),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoyasarForm(
    BuildContext context,
    CardPaymentState state,
    Function(dynamic) onResult,
    bool saveCard,
  ) {
    if (MoyasarCheckoutConfig.publishableKey.isEmpty) {
      return const Center(
        child: Text('Moyasar test publishable key is missing.'),
      );
    }
    if (state.chargeId == null || state.paymentAmountMinor == null) {
      if (state.status == CardPaymentStatus.paymentFailed) {
        return Center(
          child: TextButton(
            onPressed: () =>
                context.read<CardPaymentCubit>().prepareMoyasarPayment(),
            child: Text(S.retry),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final config = PaymentConfig(
      publishableApiKey: MoyasarCheckoutConfig.publishableKey,
      amount: state.paymentAmountMinor!,
      currency: state.paymentCurrency ?? 'SAR',
      description: 'New Coffee payment',
      // These are card schemes within the single card method. Amex is not in
      // the SDK's default allowlist, so opt in explicitly alongside the other
      // Moyasar-supported schemes.
      supportedNetworks: const [
        PaymentNetwork.mada,
        PaymentNetwork.visa,
        PaymentNetwork.masterCard,
        PaymentNetwork.amex,
        PaymentNetwork.unionPay,
      ],
      metadata: {
        'payment_id': state.chargeId!,
        'save_card_requested': saveCard ? 'true' : 'false',
      },
      givenID: state.chargeId,
      creditCard: CreditCardConfig(saveCard: saveCard, manual: false),
      applePay: MoyasarCheckoutConfig.applePayMerchantId.isEmpty
          ? null
          : ApplePayConfig(
              merchantId: MoyasarCheckoutConfig.applePayMerchantId,
              label: MoyasarCheckoutConfig.merchantName,
              manual: false,
              saveCard: false,
            ),
      samsungPay: MoyasarCheckoutConfig.samsungPayServiceId.isEmpty
          ? null
          : SamsungPayConfig(
              serviceId: MoyasarCheckoutConfig.samsungPayServiceId,
              merchantName: MoyasarCheckoutConfig.merchantName,
              orderNumber: state.chargeId,
            ),
    );
    return sdk_material.Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Localizations.override(
        context: context,
        delegates: const [
          // ignore: deprecated_member_use
          sdk_localizations.GlobalMaterialLocalizations.delegate,
        ],
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: switch (paymentMethod) {
            'stc_pay' when MoyasarCheckoutConfig.stcPayEnabled => STCPay(
              config: config,
              locale: const Localization.ar(),
              onPaymentResult: onResult,
            ),
            'apple_pay' when config.applePay != null => ApplePay(
              config: config,
              onPaymentResult: onResult,
            ),
            'samsung_pay' when config.samsungPay != null => SamsungPay(
              config: config,
              onPaymentResult: onResult,
            ),
            'card' || 'mada' => CreditCard(
              key: ValueKey('moyasar-credit-card-$saveCard'),
              config: config,
              locale: const Localization.ar(),
              onPaymentResult: onResult,
            ),
            _ => Center(child: Text(S.noPaymentMethods)),
          },
        ),
      ),
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
