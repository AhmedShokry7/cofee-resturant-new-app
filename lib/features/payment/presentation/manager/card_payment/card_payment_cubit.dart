import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';

import 'card_payment_state.dart';

class CardPaymentCubit extends Cubit<CardPaymentState> {
  CardPaymentCubit({required this.repository})
    : super(const CardPaymentState());

  final TapPaymentRepository repository;

  /// The order or subscription being paid. Set once it has been created.
  String? _orderId;
  String? _subscriptionId;

  /// When set, [chargeSavedCard] charges this card instead of asking the
  /// customer for a number again.
  String? _savedCardId;

  /// Guards a second charge while one is already on its way, whichever of the
  /// two entry points asked for it.
  bool _chargeStarted = false;

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
    bool reset = true,
  }) {
    _orderId = orderId;
    _subscriptionId = subscriptionId;
    _savedCardId = savedCardId;
    if (reset && !isClosed) {
      emit(const CardPaymentState());
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

  /// The customer pressed pay: the hosted form is asked to tokenize the card.
  ///
  /// That request is a state of the payment, not of the page, so the form's
  /// `generateToken` flag is read back from here rather than held by the widget.
  void requestCardToken() {
    if (state.isBusy) return;
    if (state.status != CardPaymentStatus.cardInputValid) {
      emit(
        state.copyWith(
          status: CardPaymentStatus.cardInputInvalid,
          errorMessage: AppCopy.invalidCardDetails,
        ),
      );
      return;
    }
    emit(
      state.copyWith(status: CardPaymentStatus.tokenizing, clearError: true),
    );
  }

  /// Charges the order with the token the hosted form reported.
  ///
  /// Tap identifies the card by the token's id and the server builds the charge
  /// from that id, so the rest of what the form hands over is not forwarded.
  Future<void> onHostedFormResult(String? response) async {
    if (state.status != CardPaymentStatus.tokenizing) return;
    final tokenId = _tokenId(response);
    if (tokenId.isEmpty) {
      onHostedFormError();
      return;
    }
    await _createCharge(sourceToken: tokenId);
  }

  /// The form could not tokenize the card, so the customer can try again.
  void onHostedFormError() {
    if (state.status != CardPaymentStatus.tokenizing) return;
    emit(
      state.copyWith(
        status: CardPaymentStatus.tokenizationFailed,
        errorMessage: AppCopy.tokenizationFailed,
      ),
    );
  }

  /// Charges the saved card [start] named, without the hosted form.
  ///
  /// The server mints a single-use token from the card id, so no card number
  /// crosses the client a second time.
  Future<void> chargeSavedCard() async {
    final savedCardId = _savedCardId;
    if (savedCardId == null || savedCardId.isEmpty) return;
    await _createCharge(savedCardId: savedCardId);
  }

  /// Verifies the charge after the customer came back from the bank.
  ///
  /// Null means there was nothing to verify: no charge, or this cubit was
  /// closed while the check was running.
  Future<PaymentOutcome?> verifyCharge() async {
    final id = state.chargeId;
    if (id == null || id.isEmpty) return null;

    emit(state.copyWith(status: CardPaymentStatus.verifying, clearError: true));

    try {
      final result = await repository.verifyCharge(id);
      if (isClosed) return null;

      if (result.verified) {
        emit(state.copyWith(status: CardPaymentStatus.paymentSucceeded));
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
      if (isClosed) return null;
      emit(
        state.copyWith(
          status: CardPaymentStatus.paymentFailed,
          errorMessage: AppCopy.paymentVerificationFailed,
        ),
      );
      return PaymentOutcome.failed;
    }
  }

  /// Creates the charge for whatever this cubit is bound to.
  ///
  /// Exactly one source is given: the id of a token the customer typed, or the
  /// saved card the server turns into a token. The order and its idempotency
  /// key are the same server id, so a retap reuses the charge instead of
  /// billing twice.
  Future<void> _createCharge({String? sourceToken, String? savedCardId}) async {
    if (_chargeStarted) return;
    final orderId = _orderId;
    final subscriptionId = _subscriptionId;
    final targetId = subscriptionId ?? orderId;
    if (targetId == null || targetId.isEmpty) return;

    _chargeStarted = true;
    emit(
      state.copyWith(
        status: CardPaymentStatus.creatingCharge,
        clearError: true,
      ),
    );

    try {
      final result = subscriptionId != null
          ? await repository.createSubscriptionCharge(
              subscriptionId: subscriptionId,
              idempotencyKey: subscriptionId,
              sourceToken: sourceToken,
              savedCardId: savedCardId,
            )
          : await repository.createCharge(
              orderId: orderId!,
              idempotencyKey: orderId,
              sourceToken: sourceToken,
              savedCardId: savedCardId,
            );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CardPaymentStatus.chargeCreated,
          chargeId: result.chargeId,
          transactionUrl: result.transactionUrl,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CardPaymentStatus.paymentFailed,
          errorMessage: AppCopy.paymentRetryLater,
        ),
      );
    } finally {
      _chargeStarted = false;
    }
  }

  /// The id Tap gave the token, empty when the form reported something that
  /// carries none.
  String _tokenId(String? response) {
    final value = response;
    if (value == null) return '';
    try {
      final map = jsonDecode(value);
      if (map is Map) {
        final id = map['id'];
        if (id is String && id.isNotEmpty) return id;
      }
    } catch (_) {}
    return '';
  }
}
