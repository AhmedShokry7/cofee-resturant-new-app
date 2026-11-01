import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_state.dart';

/// What a successful charge creation reports.
const _created = TapChargeResult(
  chargeId: chargeId,
  status: 'INITIATED',
  transactionUrl: 'https://tap.company/3ds',
);

class _FakeRepository implements TapPaymentRepository {
  _FakeRepository({this.verifyResult, this.chargeError, this.verifyError});

  final TapVerificationResult? verifyResult;
  final Object? chargeError;
  final Object? verifyError;

  int chargeCallCount = 0;
  int verifyCallCount = 0;
  String? lastSourceToken;
  String? lastSavedCardId;
  String? lastOrderId;
  String? lastIdempotencyKey;

  @override
  Future<TapChargeResult> createCharge({
    required String orderId,
    required String idempotencyKey,
    bool saveCard = false,
    String? savedCardId,
    String? sourceToken,
  }) async {
    chargeCallCount++;
    lastSourceToken = sourceToken;
    lastSavedCardId = savedCardId;
    lastOrderId = orderId;
    lastIdempotencyKey = idempotencyKey;
    if (chargeError != null) throw chargeError!;
    return _created;
  }

  @override
  Future<TapChargeResult> createSubscriptionCharge({
    required String subscriptionId,
    required String idempotencyKey,
    bool saveCard = false,
    String? savedCardId,
    String? sourceToken,
  }) async {
    chargeCallCount++;
    lastSourceToken = sourceToken;
    lastSavedCardId = savedCardId;
    lastOrderId = subscriptionId;
    lastIdempotencyKey = idempotencyKey;
    if (chargeError != null) throw chargeError!;
    return _created;
  }

  @override
  Future<TapVerificationResult> verifyCharge(String chargeId) async {
    verifyCallCount++;
    if (verifyError != null) throw verifyError!;
    return verifyResult ??
        TapVerificationResult(
          chargeId: chargeId,
          status: 'CAPTURED',
          verified: true,
          orderPaymentStatus: 'paid',
        );
  }
}

const orderId = 'order-123';
const chargeId = 'ch_456';
const tokenId = 'tok_test_123';

/// What the hosted form reports: the token Tap created, inside the payload the
/// SDK hands back.
const tokenJson =
    '{"id":"$tokenId","object":"token","type":"CARD","used":false}';

typedef Tree = ({CardPaymentCubit cubit, _FakeRepository tap});

Tree tree({
  String? orderId,
  String? subscriptionId,
  String? savedCardId,
  TapVerificationResult? verifyResult,
  Object? chargeError,
  Object? verifyError,
}) {
  final tap = _FakeRepository(
    verifyResult: verifyResult,
    chargeError: chargeError,
    verifyError: verifyError,
  );
  final cubit = CardPaymentCubit(repository: tap)
    ..start(
      orderId: orderId,
      subscriptionId: subscriptionId,
      savedCardId: savedCardId,
    );
  return (cubit: cubit, tap: tap);
}

/// A payment the customer filled correctly and pressed pay on, which is the
/// only state a token result can arrive in.
Tree tokenRequested({
  TapVerificationResult? verifyResult,
  Object? chargeError,
  Object? verifyError,
}) {
  final built = tree(
    orderId: orderId,
    verifyResult: verifyResult,
    chargeError: chargeError,
    verifyError: verifyError,
  );
  built.cubit.onCardValidInput(true);
  built.cubit.requestCardToken();
  return built;
}

void main() {
  group('card input', () {
    test('starts idle and cannot submit', () {
      final built = tree(orderId: orderId);
      expect(built.cubit.state.status, CardPaymentStatus.initial);
      expect(built.cubit.state.canSubmit, isFalse);
    });

    test('a valid card enables the pay button', () {
      final built = tree(orderId: orderId);
      built.cubit.onCardValidInput(true);
      expect(built.cubit.state.status, CardPaymentStatus.cardInputValid);
      expect(built.cubit.state.canSubmit, isTrue);
    });

    test('an invalid card disables the pay button', () {
      final built = tree(orderId: orderId);
      built.cubit.onCardValidInput(false);
      expect(built.cubit.state.status, CardPaymentStatus.cardInputInvalid);
      expect(built.cubit.state.canSubmit, isFalse);
    });

    test('input changes do not override a busy payment', () {
      final built = tokenRequested();
      built.cubit.onCardValidInput(false);
      expect(built.cubit.state.status, CardPaymentStatus.tokenizing);
    });
  });

  group('the hosted form', () {
    test('paying with a valid card asks it for a token', () {
      final built = tree(orderId: orderId);
      built.cubit.onCardValidInput(true);
      built.cubit.requestCardToken();
      expect(built.cubit.state.status, CardPaymentStatus.tokenizing);
      expect(built.cubit.state.isBusy, isTrue);
    });

    test('paying with an invalid card does not ask for a token', () {
      final built = tree(orderId: orderId);
      built.cubit.onCardValidInput(false);
      built.cubit.requestCardToken();
      expect(built.cubit.state.status, CardPaymentStatus.cardInputInvalid);
      expect(built.tap.chargeCallCount, 0);
    });

    test('a form error while tokenizing lets the customer try again', () {
      final built = tokenRequested();
      built.cubit.onHostedFormError();
      expect(built.cubit.state.status, CardPaymentStatus.tokenizationFailed);
      expect(built.cubit.state.isBusy, isFalse);
    });

    test('a result outside a token request is ignored', () async {
      final built = tree(orderId: orderId);
      built.cubit.onCardValidInput(true);
      await built.cubit.onHostedFormResult(tokenJson);
      expect(built.tap.chargeCallCount, 0);
    });
  });

  group('the charge', () {
    test('is created from the token id, not the payload', () async {
      final built = tokenRequested();
      await built.cubit.onHostedFormResult(tokenJson);
      expect(built.tap.chargeCallCount, 1);
      // The server turns the id into the card source; the rest of what the form
      // reports is not a token the charge can be built from.
      expect(built.tap.lastSourceToken, tokenId);
      expect(built.tap.lastOrderId, orderId);
      expect(built.tap.lastIdempotencyKey, orderId);
    });

    test('reports the charge id and the redirect to follow', () async {
      final built = tokenRequested();
      await built.cubit.onHostedFormResult(tokenJson);
      expect(built.cubit.state.status, CardPaymentStatus.chargeCreated);
      expect(built.cubit.state.chargeId, chargeId);
      expect(built.cubit.state.transactionUrl, 'https://tap.company/3ds');
    });

    test('a result that carries no token fails the tokenization', () async {
      for (final payload in ['not json', '{"foo":"bar"}', '']) {
        final built = tokenRequested();
        await built.cubit.onHostedFormResult(payload);
        expect(
          built.cubit.state.status,
          CardPaymentStatus.tokenizationFailed,
          reason: 'a result without a token id: $payload',
        );
        expect(built.tap.chargeCallCount, 0);
      }
    });

    test('a failed creation is a payment failure', () async {
      final built = tokenRequested(chargeError: Exception('network'));
      await built.cubit.onHostedFormResult(tokenJson);
      expect(built.cubit.state.status, CardPaymentStatus.paymentFailed);
    });

    test('a second request while one is running charges once', () async {
      final built = tokenRequested();
      await Future.wait([
        built.cubit.onHostedFormResult(tokenJson),
        built.cubit.onHostedFormResult(tokenJson),
      ]);
      expect(built.tap.chargeCallCount, 1);
    });

    test('a subscription uses the subscription charge', () async {
      final tap = _FakeRepository();
      final cubit = CardPaymentCubit(repository: tap)
        ..start(subscriptionId: 'sub-1');
      cubit.onCardValidInput(true);
      cubit.requestCardToken();
      await cubit.onHostedFormResult(tokenJson);
      expect(tap.lastOrderId, 'sub-1');
      expect(tap.lastIdempotencyKey, 'sub-1');
    });
  });

  group('a saved card', () {
    test('is charged without a token', () async {
      final built = tree(orderId: orderId, savedCardId: 'card-9');
      await built.cubit.chargeSavedCard();
      expect(built.tap.chargeCallCount, 1);
      expect(built.tap.lastSavedCardId, 'card-9');
      expect(built.tap.lastSourceToken, isNull);
      expect(built.cubit.state.status, CardPaymentStatus.chargeCreated);
    });

    test('charging one that was never named does nothing', () async {
      final built = tree(orderId: orderId);
      await built.cubit.chargeSavedCard();
      expect(built.tap.chargeCallCount, 0);
    });

    test('two requests at once charge once', () async {
      final built = tree(orderId: orderId, savedCardId: 'card-9');
      await Future.wait([
        built.cubit.chargeSavedCard(),
        built.cubit.chargeSavedCard(),
      ]);
      expect(built.tap.chargeCallCount, 1);
    });
  });

  group('verifying after the bank', () {
    Future<Tree> charged({TapVerificationResult? verifyResult}) async {
      final built = tokenRequested(verifyResult: verifyResult);
      await built.cubit.onHostedFormResult(tokenJson);
      return built;
    }

    test('a verified charge is succeeded', () async {
      final built = await charged();
      expect(await built.cubit.verifyCharge(), PaymentOutcome.succeeded);
      expect(built.cubit.state.status, CardPaymentStatus.paymentSucceeded);
    });

    test('a pending order is pending', () async {
      final built = await charged(
        verifyResult: const TapVerificationResult(
          chargeId: chargeId,
          status: 'PENDING',
          verified: false,
          orderPaymentStatus: 'pending',
        ),
      );
      expect(await built.cubit.verifyCharge(), PaymentOutcome.pending);
      expect(built.cubit.state.status, CardPaymentStatus.paymentPending);
    });

    test('a rejected charge is failed', () async {
      final built = await charged(
        verifyResult: const TapVerificationResult(
          chargeId: chargeId,
          status: 'FAILED',
          verified: false,
          orderPaymentStatus: 'failed',
        ),
      );
      expect(await built.cubit.verifyCharge(), PaymentOutcome.failed);
      expect(built.cubit.state.status, CardPaymentStatus.paymentFailed);
    });

    test('a verification error is failed', () async {
      final built = tokenRequested(verifyError: Exception('timeout'));
      await built.cubit.onHostedFormResult(tokenJson);
      expect(await built.cubit.verifyCharge(), PaymentOutcome.failed);
      expect(built.cubit.state.status, CardPaymentStatus.paymentFailed);
    });

    test('nothing is verified before a charge exists', () async {
      final built = tree(orderId: orderId);
      expect(await built.cubit.verifyCharge(), isNull);
      expect(built.tap.verifyCallCount, 0);
    });
  });
}
