import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/locale/app_copy.dart';

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

/// How the verification of a charge after the bank's page ended.
///
/// The redirect happens outside the app, so the customer coming back is the
/// only moment the outcome can be read; this is what the page acts on.
enum PaymentOutcome { succeeded, pending, failed }

@immutable
class CardPaymentState {
  const CardPaymentState({
    this.status = CardPaymentStatus.initial,
    this.errorMessage,
    this.chargeId,
    this.transactionUrl,
  });

  final CardPaymentStatus status;
  final AppCopy? errorMessage;

  /// [errorMessage] in the language the customer is reading the page in.
  String? get errorMessageCopy => errorMessage?.copy;
  final String? chargeId;
  final String? transactionUrl;

  bool get isBusy =>
      status == CardPaymentStatus.tokenizing ||
      status == CardPaymentStatus.creatingCharge ||
      status == CardPaymentStatus.verifying;

  bool get canSubmit => status == CardPaymentStatus.cardInputValid && !isBusy;

  CardPaymentState copyWith({
    CardPaymentStatus? status,
    AppCopy? errorMessage,
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
