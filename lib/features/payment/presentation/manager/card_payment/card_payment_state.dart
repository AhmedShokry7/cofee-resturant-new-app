import 'package:flutter/foundation.dart';

enum CardPaymentStatus {
  initial,
  cardInputInvalid,
  cardInputValid,
  tokenizing,
  tokenizationFailed,
  creatingCharge,
  chargeCreated,
  verifying,
  paymentPending,
  paymentFailed,
  paymentSucceeded,
}

@immutable
class CardPaymentState {
  const CardPaymentState({
    this.status = CardPaymentStatus.initial,
    this.errorMessage,
    this.chargeId,
    this.transactionUrl,
  });

  final CardPaymentStatus status;
  final String? errorMessage;
  final String? chargeId;
  final String? transactionUrl;

  bool get isBusy =>
      status == CardPaymentStatus.tokenizing ||
      status == CardPaymentStatus.creatingCharge ||
      status == CardPaymentStatus.verifying;

  bool get canSubmit =>
      status == CardPaymentStatus.cardInputValid && !isBusy;

  CardPaymentState copyWith({
    CardPaymentStatus? status,
    String? errorMessage,
    bool clearError = false,
    String? chargeId,
    bool clearChargeId = false,
    String? transactionUrl,
    bool clearTransactionUrl = false,
  }) {
    return CardPaymentState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      chargeId: clearChargeId ? null : (chargeId ?? this.chargeId),
      transactionUrl: clearTransactionUrl
          ? null
          : (transactionUrl ?? this.transactionUrl),
    );
  }
}
