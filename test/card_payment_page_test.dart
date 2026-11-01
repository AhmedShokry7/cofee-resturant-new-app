import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_state.dart';

void main() {
  group('CardPaymentState', () {
    test('initial state has correct defaults', () {
      const state = CardPaymentState();
      expect(state.status, CardPaymentStatus.initial);
      expect(state.isBusy, isFalse);
      expect(state.canSubmit, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.chargeId, isNull);
      expect(state.transactionUrl, isNull);
    });

    test('cardInputValid allows submit when not busy', () {
      const state = CardPaymentState(status: CardPaymentStatus.cardInputValid);
      expect(state.canSubmit, isTrue);
      expect(state.isBusy, isFalse);
    });

    test('cardInputInvalid does not allow submit', () {
      const state = CardPaymentState(
        status: CardPaymentStatus.cardInputInvalid,
      );
      expect(state.canSubmit, isFalse);
    });

    test('tokenizing state is busy and cannot submit', () {
      const state = CardPaymentState(status: CardPaymentStatus.tokenizing);
      expect(state.isBusy, isTrue);
      expect(state.canSubmit, isFalse);
    });

    test('creatingCharge state is busy', () {
      const state = CardPaymentState(status: CardPaymentStatus.creatingCharge);
      expect(state.isBusy, isTrue);
    });

    test('verifying state is busy', () {
      const state = CardPaymentState(status: CardPaymentStatus.verifying);
      expect(state.isBusy, isTrue);
    });

    test('chargeCreated state preserves chargeId and transactionUrl', () {
      const state = CardPaymentState(
        status: CardPaymentStatus.chargeCreated,
        chargeId: 'ch_123',
        transactionUrl: 'https://tap.company/3ds',
      );
      expect(state.chargeId, 'ch_123');
      expect(state.transactionUrl, 'https://tap.company/3ds');
    });

    test('copyWith updates status', () {
      const state = CardPaymentState();
      final updated = state.copyWith(status: CardPaymentStatus.cardInputValid);
      expect(updated.status, CardPaymentStatus.cardInputValid);
    });

    test('copyWith clears error when clearError is true', () {
      const state = CardPaymentState(errorMessage: 'error');
      final updated = state.copyWith(clearError: true);
      expect(updated.errorMessage, isNull);
    });

    test('copyWith preserves error when clearError is false', () {
      const state = CardPaymentState(errorMessage: 'error');
      final updated = state.copyWith(status: CardPaymentStatus.initial);
      expect(updated.errorMessage, 'error');
    });

    test('copyWith clears chargeId when clearChargeId is true', () {
      const state = CardPaymentState(chargeId: 'ch_123');
      final updated = state.copyWith(clearChargeId: true);
      expect(updated.chargeId, isNull);
    });

    test('copyWith clears transactionUrl when clearTransactionUrl is true', () {
      const state = CardPaymentState(transactionUrl: 'https://example.com');
      final updated = state.copyWith(clearTransactionUrl: true);
      expect(updated.transactionUrl, isNull);
    });

    test('all busy statuses are correctly identified', () {
      expect(CardPaymentStatus.tokenizing.isBusyStatus, isTrue);
      expect(CardPaymentStatus.creatingCharge.isBusyStatus, isTrue);
      expect(CardPaymentStatus.verifying.isBusyStatus, isTrue);
      expect(CardPaymentStatus.initial.isBusyStatus, isFalse);
      expect(CardPaymentStatus.cardInputValid.isBusyStatus, isFalse);
      expect(CardPaymentStatus.paymentSucceeded.isBusyStatus, isFalse);
    });
  });

  group('CardPaymentStatus transitions', () {
    test('initial -> cardInputValid on valid input', () {
      const initial = CardPaymentState();
      final valid = initial.copyWith(status: CardPaymentStatus.cardInputValid);
      expect(valid.status, CardPaymentStatus.cardInputValid);
      expect(valid.canSubmit, isTrue);
    });

    test('cardInputValid -> tokenizing on createCharge', () {
      const valid = CardPaymentState(status: CardPaymentStatus.cardInputValid);
      final tokenizing = valid.copyWith(status: CardPaymentStatus.tokenizing);
      expect(tokenizing.isBusy, isTrue);
      expect(tokenizing.canSubmit, isFalse);
    });

    test('tokenizing -> tokenizationFailed on null token', () {
      const tokenizing = CardPaymentState(status: CardPaymentStatus.tokenizing);
      final failed = tokenizing.copyWith(
        status: CardPaymentStatus.tokenizationFailed,
        errorMessage: 'Tokenization failed',
      );
      expect(failed.status, CardPaymentStatus.tokenizationFailed);
      expect(failed.errorMessage, 'Tokenization failed');
    });

    test('tokenizing -> creatingCharge on valid token', () {
      const tokenizing = CardPaymentState(status: CardPaymentStatus.tokenizing);
      final creating = tokenizing.copyWith(
        status: CardPaymentStatus.creatingCharge,
      );
      expect(creating.status, CardPaymentStatus.creatingCharge);
      expect(creating.isBusy, isTrue);
    });

    test('creatingCharge -> chargeCreated on success', () {
      const creating = CardPaymentState(
        status: CardPaymentStatus.creatingCharge,
      );
      final created = creating.copyWith(
        status: CardPaymentStatus.chargeCreated,
        chargeId: 'ch_123',
        transactionUrl: 'https://tap.company/3ds',
      );
      expect(created.status, CardPaymentStatus.chargeCreated);
      expect(created.chargeId, 'ch_123');
    });

    test('chargeCreated -> verifying on verifyCharge', () {
      const created = CardPaymentState(
        status: CardPaymentStatus.chargeCreated,
        chargeId: 'ch_123',
      );
      final verifying = created.copyWith(status: CardPaymentStatus.verifying);
      expect(verifying.status, CardPaymentStatus.verifying);
      expect(verifying.isBusy, isTrue);
    });

    test('verifying -> paymentSucceeded on verified', () {
      const verifying = CardPaymentState(status: CardPaymentStatus.verifying);
      final succeeded = verifying.copyWith(
        status: CardPaymentStatus.paymentSucceeded,
      );
      expect(succeeded.status, CardPaymentStatus.paymentSucceeded);
      expect(succeeded.isBusy, isFalse);
    });

    test('verifying -> paymentPending on pending', () {
      const verifying = CardPaymentState(status: CardPaymentStatus.verifying);
      final pending = verifying.copyWith(
        status: CardPaymentStatus.paymentPending,
      );
      expect(pending.status, CardPaymentStatus.paymentPending);
    });

    test('verifying -> paymentFailed on failed', () {
      const verifying = CardPaymentState(status: CardPaymentStatus.verifying);
      final failed = verifying.copyWith(
        status: CardPaymentStatus.paymentFailed,
        errorMessage: 'Payment failed',
      );
      expect(failed.status, CardPaymentStatus.paymentFailed);
      expect(failed.errorMessage, 'Payment failed');
    });
  });
}

extension on CardPaymentStatus {
  bool get isBusyStatus =>
      this == CardPaymentStatus.tokenizing ||
      this == CardPaymentStatus.creatingCharge ||
      this == CardPaymentStatus.verifying;
}
