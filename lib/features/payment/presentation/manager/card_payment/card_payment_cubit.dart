import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';

import 'card_payment_state.dart';

class CardPaymentCubit extends Cubit<CardPaymentState> {
  CardPaymentCubit({
    required this.repository,
    this.sourceTokenProvider,
  }) : super(const CardPaymentState());

  final TapPaymentRepository repository;

  /// Provides a one-time token from the hosted card form. Null when the cubit
  /// was built to charge a saved card instead.
  final Future<String?> Function()? sourceTokenProvider;

  /// The order or subscription being paid. Set once it has been created.
  String? _orderId;
  String? _subscriptionId;

  /// When set, [createCharge] charges this saved card instead of asking for a
  /// token -- the server mints a single-use token from the card id, so no card
  /// number crosses the client a second time.
  String? _savedCardId;

  /// Binds the cubit to an order/subscription and, optionally, a saved card to charge.
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
        emit(state.copyWith(status: CardPaymentStatus.cardInputValid, clearError: true));
      }
    } else {
      if (state.status != CardPaymentStatus.cardInputInvalid) {
        emit(state.copyWith(status: CardPaymentStatus.cardInputInvalid, clearError: true));
      }
    }
  }

  /// Creates the charge for the order or subscription this cubit is bound to.
  ///
  /// [sourceToken] is the token the hosted card form produced. It is passed
  /// in by the caller that owns the form, because the token only exists there;
  /// [sourceTokenProvider] stays available for callers that fetch the token
  /// themselves. Without either, the attempt fails as a tokenization failure
  /// instead of leaving the screen stuck in "tokenizing".
  Future<void> createCharge({String? sourceToken}) async {
    if (state.isBusy) return;
    final orderId = _orderId;
    final subscriptionId = _subscriptionId;
    final targetId = subscriptionId ?? orderId;
    if (targetId == null || targetId.isEmpty) return;

    // A saved card needs no token: the server mints one from the card id.
    final savedCard = _savedCardId;
    if (savedCard != null && savedCard.isNotEmpty) {
      return createChargeFromSavedCard(savedCard);
    }

    if (state.status != CardPaymentStatus.cardInputValid) {
      emit(state.copyWith(
        status: CardPaymentStatus.cardInputInvalid,
        errorMessage: S.invalidCardDetails,
      ));
      return;
    }

    emit(state.copyWith(status: CardPaymentStatus.tokenizing, clearError: true));

    final provider = sourceTokenProvider;
    final token = sourceToken ?? (provider == null ? null : await provider());
    if (isClosed) return;

    if (token == null || token.isEmpty) {
      emit(state.copyWith(
        status: CardPaymentStatus.tokenizationFailed,
        errorMessage: S.tokenizationFailed,
      ));
      return;
    }

    emit(state.copyWith(status: CardPaymentStatus.creatingCharge));

    try {
      final result = subscriptionId != null
          ? await repository.createSubscriptionCharge(
              subscriptionId: subscriptionId,
              idempotencyKey: subscriptionId,
              sourceToken: token,
            )
          : await repository.createCharge(
              orderId: orderId!,
              idempotencyKey: orderId,
              sourceToken: token,
            );
      if (isClosed) return;

      emit(state.copyWith(
        status: CardPaymentStatus.chargeCreated,
        chargeId: result.chargeId,
        transactionUrl: result.transactionUrl,
      ));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(
        status: CardPaymentStatus.paymentFailed,
        errorMessage: S.paymentRetryLater,
      ));
    }
  }

  Future<String?> verifyCharge() async {
    final id = state.chargeId;
    if (id == null || id.isEmpty) return null;

    emit(state.copyWith(status: CardPaymentStatus.verifying, clearError: true));

    try {
      final result = await repository.verifyCharge(id);
      if (isClosed) return null;

      if (result.verified) {
        emit(state.copyWith(status: CardPaymentStatus.paymentSucceeded));
        return 'succeeded';
      } else if (result.orderPaymentStatus == 'pending') {
        emit(state.copyWith(status: CardPaymentStatus.paymentPending));
        return 'pending';
      } else {
        emit(state.copyWith(
          status: CardPaymentStatus.paymentFailed,
          errorMessage: S.paymentNotCompleted,
        ));
        return 'failed';
      }
    } catch (error) {
      if (isClosed) return null;
      emit(state.copyWith(
        status: CardPaymentStatus.paymentFailed,
        errorMessage: S.paymentVerificationFailed,
      ));
      return 'failed';
    }
  }

/// Charges a card the customer already saved, without opening the hosted form.
  ///
  /// The server mints a single-use token from the saved card id and charges that,
  /// so no card number ever crosses the client a second time.
  Future<void> createChargeFromSavedCard(String savedCardId) async {
    if (state.isBusy) return;
    final orderId = _orderId;
    final subscriptionId = _subscriptionId;
    final targetId = subscriptionId ?? orderId;
    if (targetId == null || targetId.isEmpty) return;
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
              savedCardId: savedCardId,
            )
          : await repository.createCharge(
              orderId: orderId!,
              idempotencyKey: orderId,
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
          errorMessage: S.paymentRetryLater,
        ),
      );
    }
  }

  String extractTokenId(String successResponse) {
    try {
      final map = jsonDecode(successResponse);
      if (map is Map) {
        final id = map['id'];
        if (id is String && id.isNotEmpty) return id;
      }
    } catch (_) {}
    return '';
  }
}
