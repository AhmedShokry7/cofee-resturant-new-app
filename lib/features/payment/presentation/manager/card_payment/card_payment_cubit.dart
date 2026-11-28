import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/features/payment/data/repositories/payment_repository.dart';
import 'package:new_coffee/features/payment/data/moyasar_checkout_config.dart';
import 'package:new_coffee/features/payment/data/repositories/moyasar_payment_repository.dart';

import 'card_payment_state.dart';

class CardPaymentCubit extends Cubit<CardPaymentState> {
  CardPaymentCubit({required this.repository})
    : super(const CardPaymentState());

  final PaymentRepository repository;

  /// The order or subscription being paid. Set once it has been created.
  String? _orderId;
  String? _subscriptionId;

  /// When set, [chargeSavedCard] charges this card instead of asking the
  /// customer for a number again.
  String? _savedCardId;
  Map<String, dynamic>? _checkoutDraft;
  String? _checkoutDraftKey;

  /// Guards a second charge while one is already on its way, whichever of the
  /// two entry points asked for it.
  bool _chargeStarted = false;
  int _attempt = 0;

  /// Binds the cubit to an order/subscription and, optionally, a saved card to
  /// charge.
  ///
  /// [reset] clears the state of a previous attempt. It is false when the
  /// charge for this very order already exists (the saved-card flow creates
  /// the charge before the payment page is opened), so the page keeps the
  /// charge id and the redirect URL it has to follow.
  void start({
    String? orderId,
    String? subscriptionId,
    String? savedCardId,
    Map<String, dynamic>? checkoutDraft,
    bool reset = true,
  }) {
    if (reset) {
      _attempt++;
      _chargeStarted = false;
    }
    _orderId = orderId;
    _subscriptionId = subscriptionId;
    _savedCardId = savedCardId;
    _checkoutDraft = checkoutDraft;
    _checkoutDraftKey = checkoutDraft?['idempotency_key']?.toString();
    if (reset && !isClosed) {
      emit(const CardPaymentState());
    }
  }

  /// Whether a charge created before the payment page opened belongs to this
  /// exact saved-card checkout. The app-wide cubit can still hold a charge
  /// from an earlier order, so status and charge ID alone are not sufficient.
  bool hasChargeCreatedFor({
    required String? orderId,
    required String? subscriptionId,
    required String? savedCardId,
    required String? checkoutKey,
  }) {
    return state.status == CardPaymentStatus.chargeCreated &&
        (state.chargeId ?? '').isNotEmpty &&
        _orderId == orderId &&
        _subscriptionId == subscriptionId &&
        _savedCardId == savedCardId &&
        _checkoutDraftKey == checkoutKey;
  }

  /// Prices the payment on Supabase before the Moyasar SDK opens its form.
  /// The returned ID is also sent as Moyasar's `givenID`, binding verification
  /// to this user-owned order and preventing a client supplied price from
  /// being accepted as proof of payment.
  Future<void> prepareMoyasarPayment() async {
    if (!MoyasarCheckoutConfig.enabled || state.isBusy) return;
    final repository = this.repository;
    if (repository is! MoyasarPaymentOperations) {
      emit(
        state.copyWith(
          status: CardPaymentStatus.paymentFailed,
          errorMessage: AppCopy.paymentRetryLater,
        ),
      );
      return;
    }
    final moyasarRepository = repository as MoyasarPaymentOperations;
    final attempt = _attempt;
    emit(
      state.copyWith(
        status: CardPaymentStatus.creatingCharge,
        clearError: true,
        clearChargeId: true,
        clearTransactionUrl: true,
      ),
    );
    try {
      final intent = await moyasarRepository.preparePayment(
        orderId: _orderId,
        subscriptionId: _subscriptionId,
        checkoutDraft: _checkoutDraft,
      );
      if (isClosed || attempt != _attempt) return;
      if (intent.paymentId.isEmpty || intent.amount < 100) {
        throw StateError('Invalid payment intent');
      }
      emit(
        state.copyWith(
          status: CardPaymentStatus.chargeCreated,
          chargeId: intent.paymentId,
          paymentAmountMinor: intent.amount,
          paymentCurrency: intent.currency,
        ),
      );
    } catch (_) {
      if (isClosed || attempt != _attempt) return;
      emit(
        state.copyWith(
          status: CardPaymentStatus.paymentFailed,
          errorMessage: AppCopy.paymentRetryLater,
        ),
      );
    }
  }

  void onCardValidInput(bool isValid) {
    if (state.isBusy) return;
    if (isValid) {
      if (state.status != CardPaymentStatus.cardInputValid) {
        emit(
          state.copyWith(
            status: CardPaymentStatus.cardInputValid,
            clearError: true,
          ),
        );
      }
    } else {
      if (state.status != CardPaymentStatus.cardInputInvalid) {
        emit(
          state.copyWith(
            status: CardPaymentStatus.cardInputInvalid,
            clearError: true,
          ),
        );
      }
    }
  }

  /// Charges the saved card [start] named, without the hosted form.
  ///
  /// The server mints a single-use token from the card id, so no card number
  /// crosses the client a second time.
  Future<void> chargeSavedCard() async {
    final savedCardId = _savedCardId;
    if (savedCardId == null || savedCardId.isEmpty) return;
    final paymentRepository = repository;
    if (paymentRepository is! MoyasarPaymentOperations ||
        !MoyasarCheckoutConfig.enabled) {
      emit(
        state.copyWith(
          status: CardPaymentStatus.paymentFailed,
          errorMessage: AppCopy.paymentRetryLater,
        ),
      );
      return;
    }
    await _createMoyasarSavedCardCharge(savedCardId);
  }

  Future<void> _createMoyasarSavedCardCharge(String savedCardId) async {
    final attempt = _attempt;
    if (_chargeStarted) return;
    final orderId = _orderId;
    final subscriptionId = _subscriptionId;
    if ((orderId == null || orderId.isEmpty) &&
        (subscriptionId == null || subscriptionId.isEmpty) &&
        _checkoutDraft == null) {
      return;
    }
    _chargeStarted = true;
    emit(
      state.copyWith(
        status: CardPaymentStatus.creatingCharge,
        clearError: true,
      ),
    );
    try {
      final result = await (repository as MoyasarPaymentOperations)
          .createSavedCardCharge(
            orderId: orderId,
            subscriptionId: subscriptionId,
            checkoutDraft: _checkoutDraft,
            savedCardId: savedCardId,
          );
      if (isClosed || attempt != _attempt) return;
      emit(
        state.copyWith(
          status: CardPaymentStatus.chargeCreated,
          chargeId: result.chargeId,
          transactionUrl: result.transactionUrl,
        ),
      );
    } catch (_) {
      if (isClosed || attempt != _attempt) return;
      emit(
        state.copyWith(
          status: CardPaymentStatus.paymentFailed,
          errorMessage: AppCopy.paymentRetryLater,
        ),
      );
    } finally {
      if (attempt == _attempt) _chargeStarted = false;
    }
  }

  /// Verifies the charge after the customer came back from the bank.
  ///
  /// Null means there was nothing to verify: no charge, or this cubit was
  /// closed while the check was running.
  Future<PaymentOutcome?> verifyCharge() async {
    final attempt = _attempt;
    final id = state.chargeId;
    if (id == null ||
        id.isEmpty ||
        state.status == CardPaymentStatus.verifying) {
      return null;
    }

    emit(state.copyWith(status: CardPaymentStatus.verifying, clearError: true));

    try {
      final result = await repository.verifyCharge(id);
      if (isClosed || attempt != _attempt || state.chargeId != id) return null;

      if (result.chargeId != id) {
        throw StateError('Verification returned another payment');
      }
      if (result.verified &&
          result.orderPaymentStatus == 'paid' &&
          const {'paid', 'captured'}.contains(result.status.toLowerCase())) {
        emit(
          state.copyWith(
            status: CardPaymentStatus.paymentSucceeded,
            savedCardStatus: result.savedCardStatus,
            finalizedOrder: result.finalizedOrder,
          ),
        );
        return PaymentOutcome.succeeded;
      } else if (result.orderPaymentStatus == 'pending') {
        emit(state.copyWith(status: CardPaymentStatus.paymentPending));
        return PaymentOutcome.pending;
      } else {
        emit(
          state.copyWith(
            status: CardPaymentStatus.paymentFailed,
            errorMessage: AppCopy.paymentNotCompleted,
          ),
        );
        return PaymentOutcome.failed;
      }
    } catch (error) {
      if (isClosed || attempt != _attempt || state.chargeId != id) return null;
      emit(
        state.copyWith(
          status: CardPaymentStatus.paymentFailed,
          errorMessage: AppCopy.paymentVerificationFailed,
        ),
      );
      return PaymentOutcome.failed;
    }
  }
}
