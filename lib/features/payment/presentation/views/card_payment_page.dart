import 'package:card_flutter/card_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_state.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/shared/widgets/primary_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class CardPaymentPage extends StatefulWidget {
  const CardPaymentPage({
    super.key,
    required this.orderId,
    required this.idempotencyKey,
    required this.publicKey,
    required this.sdkConfiguration,
    this.savedCardId,
  });

  final String orderId;
  final String idempotencyKey;
  final String publicKey;
  final Map<String, dynamic> sdkConfiguration;

  /// When set, the page charges this saved card instead of showing the hosted
  /// form. The bottom bar sets it after placing the order.
  final String? savedCardId;

  static const routeName = "cardPaymentRoute";

  @override
  State<CardPaymentPage> createState() => _CardPaymentPageState();
}

class _CardPaymentPageState extends State<CardPaymentPage> {
  bool _generateToken = false;
  bool _tokenRequested = false;
  String? _tokenResponse;

  Map<String, dynamic> get _config {
    final config = Map<String, dynamic>.from(widget.sdkConfiguration);
    config['operator'] = {
      'publicKey': widget.publicKey,
    };
    config['scope'] = 'Token';
    config['purpose'] = 'Charge';
    config['order'] = {
      'id': widget.orderId,
      'currency': 'SAR',
      'amount': 1.0,
      'reference': widget.orderId,
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

  Future<String?> _tokenSource() async {
    return _tokenResponse;
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
    _tokenResponse = value;
    _generateToken = false;
    context.read<CardPaymentCubit>().createCharge();
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
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _verifyAndNavigate() async {
    final cubit = context.read<CardPaymentCubit>();
    final result = await cubit.verifyCharge();
    if (!mounted) return;

    if (result == 'succeeded') {
      Navigator.of(context).pushNamedAndRemoveUntil(
        PaymentSuccessPage.routeName,
        (route) => route.isFirst,
      );
    } else if (result == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.paymentProcessing)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.paymentFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CardPaymentCubit>();
    cubit.start(orderId: widget.orderId, savedCardId: widget.savedCardId);
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
        onVerifyAndNavigate: _verifyAndNavigate,
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
    required this.onVerifyAndNavigate,
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
  final VoidCallback onVerifyAndNavigate;

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
                child: SingleChildScrollView(
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
