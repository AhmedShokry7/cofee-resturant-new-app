import 'dart:async';

import 'package:card_flutter/card_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_state.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/shared/widgets/primary_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class CardPaymentPage extends StatefulWidget {
  const CardPaymentPage({
    super.key,
    this.orderId = '',
    this.subscriptionId,
    required this.idempotencyKey,
    required this.publicKey,
    required this.sdkConfiguration,
    this.savedCardId,
    this.amount = 0,
    this.currency = 'SAR',
  });

  /// The server id of the order being paid (a uuid), never the order number.
  final String orderId;
  final String? subscriptionId;
  final String idempotencyKey;
  final String publicKey;
  final Map<String, dynamic> sdkConfiguration;

  /// When set, the page charges this saved card instead of showing the hosted
  /// form. The bottom bar sets it after placing the order.
  final String? savedCardId;

  /// The amount the customer is charged, in [currency].
  ///
  /// The card form shows this figure, so it has to be the real one: the
  /// server charges `orders.grand_total` (or the plan price for a
  /// subscription), and a form that shows anything else is a lie.
  final double amount;
  final String currency;

  static const routeName = "cardPaymentRoute";

  @override
  State<CardPaymentPage> createState() => _CardPaymentPageState();
}

class _CardPaymentPageState extends State<CardPaymentPage>
    with WidgetsBindingObserver {
  bool _generateToken = false;
  bool _tokenRequested = false;

  /// True once the 3DS page was opened. The charge is only verified when the
  /// app comes back from it, so this is what tells the resume handler that
  /// there is something to verify.
  bool _redirectLaunched = false;

  Map<String, dynamic> get _config {
    final config = Map<String, dynamic>.from(widget.sdkConfiguration);
    config['operator'] = {
      'publicKey': widget.publicKey,
    };
    config['scope'] = 'Token';
    config['purpose'] = 'Charge';
    final targetId = widget.subscriptionId ?? widget.orderId;
    config['order'] = {
      'id': targetId,
      'currency': widget.currency,
      // The card form shows this amount, so it is the amount the customer is
      // charged. A caller that does not know it keeps the previous nominal
      // figure rather than showing nothing at all.
      'amount': widget.amount > 0 ? widget.amount : 1.0,
      'reference': targetId,
      'description': '',
    };
    config['customer'] = {
      'name': [
        {'lang': 'en', 'first': '', 'last': ''}
      ],
      'contact': {'email': ''},
      'editable': false,
    };
    config['acceptance'] = {
      'supportedSchemes': ['VISA', 'MASTERCARD', 'AMERICAN_EXPRESS'],
      'supportedFundSource': ['CREDIT', 'DEBIT'],
      'supportedPaymentAuthentications': ['3DS'],
    };
    config['interface'] = {
      'locale': 'ar',
      'theme': 'light',
      'edges': 'curved',
      'colorStyle': 'colored',
      'loader': true,
    };
    config['features'] = {
      'customerCards': {'saveCard': false, 'autoSave': false},
      'acceptanceBadge': true,
    };
    return config;
  }

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

  void _onValidInput(String? value) {
    if (value == null) return;
    context.read<CardPaymentCubit>().onCardValidInput(value.toLowerCase() == 'true');
  }

  void _onSuccess(String? value) {
    _tokenRequested = false;
    if (value == null) return;
    final tokenId = context.read<CardPaymentCubit>().extractTokenId(value);
    if (tokenId.isEmpty) {
      return;
    }
    _generateToken = false;
    // The token only exists here, so it is handed to the cubit directly.
    context.read<CardPaymentCubit>().createCharge(sourceToken: value);
  }

  void _onError(String? value) {
    _tokenRequested = false;
    _generateToken = false;
  }

  Future<void> _onPayPressed() async {
    final cubit = context.read<CardPaymentCubit>();
    if (cubit.state.isBusy) return;
    if (cubit.state.status != CardPaymentStatus.cardInputValid) return;

    if (_tokenRequested) return;
    _tokenRequested = true;
    setState(() {
      _generateToken = true;
    });
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
    final result = await cubit.verifyCharge();
    if (!mounted) return;
    if (result == 'succeeded') {
      _finish();
    } else if (result == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.paymentProcessing)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cubit.state.errorMessage ?? S.paymentFailed)),
      );
    }
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
    final cubit = context.read<CardPaymentCubit>();
    return BlocProvider.value(
      value: cubit,
      child: _CardPaymentView(
        generateToken: _generateToken,
        onPayPressed: _onPayPressed,
        onValidInput: _onValidInput,
        onSuccess: _onSuccess,
        onError: _onError,
        onReady: () {},
        onFocus: () {},
        sdkConfiguration: _config,
        on3DSLaunch: _launch3DS,
        chargesSavedCard: _chargesSavedCard,
      ),
    );
  }
}

class _CardPaymentView extends StatelessWidget {
  const _CardPaymentView({
    required this.generateToken,
    required this.onPayPressed,
    required this.onValidInput,
    required this.onSuccess,
    required this.onError,
    required this.onReady,
    required this.onFocus,
    required this.sdkConfiguration,
    required this.on3DSLaunch,
    required this.chargesSavedCard,
  });

  final bool generateToken;
  final VoidCallback onPayPressed;
  final Function(String?) onValidInput;
  final Function(String?) onSuccess;
  final Function(String?) onError;
  final VoidCallback onReady;
  final VoidCallback onFocus;
  final Map<String, dynamic> sdkConfiguration;
  final Function(String) on3DSLaunch;

  /// A stored card is charged without the card form: there is nothing for the
  /// customer to type.
  final bool chargesSavedCard;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CardPaymentCubit, CardPaymentState>(
      listener: (context, state) {
        if (state.status == CardPaymentStatus.chargeCreated &&
            state.transactionUrl != null &&
            state.transactionUrl!.isNotEmpty) {
          on3DSLaunch(state.transactionUrl!);
        }
      },
      builder: (context, state) {
        final canPay = state.canSubmit;
        return Scaffold(
          appBar: AppBar(title: Text(S.payment)),
          body: Column(
            children: [
              Expanded(
                child: chargesSavedCard
                    ? _SavedCardPaymentNotice(state: state)
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(SpacingTokens.lg.w),
                        child: TapCardViewWidget(
                          sdkConfiguration: sdkConfiguration,
                          generateToken: generateToken,
                          onValidInput: onValidInput,
                          onSuccess: onSuccess,
                          onError: onError,
                          onReady: onReady,
                          onFocus: onFocus,
                          showLoading: true,
                        ),
                      ),
              ),
              if (state.errorMessage != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: SpacingTokens.lg.w,
                    vertical: SpacingTokens.sm.h,
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(color: AppColor.errorColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!chargesSavedCard)
                PrimaryBottomBar(
                  text: S.confirmPayment,
                  isLoading: state.isBusy,
                  onPressed: canPay ? onPayPressed : () {},
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
    final waiting = state.isBusy ||
        state.status == CardPaymentStatus.chargeCreated ||
        state.status == CardPaymentStatus.paymentPending;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (waiting)
              const CircularProgressIndicator()
            else
              Icon(
                HugeIcons.strokeRoundedCreditCard,
                size: 48.w,
                color: AppColor.primaryColor,
              ),
            SizedBox(height: SpacingTokens.md.h),
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
