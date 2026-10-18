import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_state.dart';

class _FakeRepository implements TapPaymentRepository {
  _FakeRepository({
    this.chargeResult,
    this.verifyResult,
    this.chargeError,
    this.verifyError,
  });

  final TapChargeResult? chargeResult;
  final TapVerificationResult? verifyResult;
  final Object? chargeError;
  final Object? verifyError;

  int chargeCallCount = 0;
  int verifyCallCount = 0;
  String? lastSourceToken;
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
    lastOrderId = orderId;
    lastIdempotencyKey = idempotencyKey;
    if (chargeError != null) throw chargeError!;
    return chargeResult!;
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
    lastOrderId = subscriptionId;
    lastIdempotencyKey = idempotencyKey;
    if (chargeError != null) throw chargeError!;
    return chargeResult!;
  }

  @override
  Future<TapVerificationResult> verifyCharge(String chargeId) async {
    verifyCallCount++;
    if (verifyError != null) throw verifyError!;
    return verifyResult!;
  }
}

void main() {
  const orderId = 'order-123';
  const chargeId = 'ch_456';
  const tokenJson =
      '{"id":"tok_test_123","object":"token","type":"CARD","used":false}';

  late _FakeRepository repository;
  late CardPaymentCubit cubit;

  CardPaymentCubit createCubit({String? token, Object? chargeError, Object? verifyError}) {
    repository = _FakeRepository(
      chargeResult: TapChargeResult(
        chargeId: chargeId,
        status: 'INITIATED',
        transactionUrl: 'https://tap.company/3ds',
      ),
      verifyResult: TapVerificationResult(
        chargeId: chargeId,
        status: 'CAPTURED',
        verified: true,
        orderPaymentStatus: 'paid',
      ),
      chargeError: chargeError,
      verifyError: verifyError,
    );
    return CardPaymentCubit(repository: repository, sourceTokenProvider: () async => token)..start(orderId: orderId);
  }

  group('CardPaymentCubit', () {
    test('initial state is correct', () {
      cubit = createCubit(token: tokenJson);
      expect(cubit.state.status, CardPaymentStatus.initial);
      expect(cubit.state.isBusy, isFalse);
      expect(cubit.state.canSubmit, isFalse);
    });

    test('onCardValidInput(true) transitions to cardInputValid', () {
      cubit = createCubit(token: tokenJson);
      cubit.onCardValidInput(true);
      expect(cubit.state.status, CardPaymentStatus.cardInputValid);
      expect(cubit.state.canSubmit, isTrue);
    });

    test('onCardValidInput(false) transitions to cardInputInvalid', () {
      cubit = createCubit(token: tokenJson);
      cubit.onCardValidInput(false);
      expect(cubit.state.status, CardPaymentStatus.cardInputInvalid);
      expect(cubit.state.canSubmit, isFalse);
    });

    test('onCardValidInput does not override busy state', () {
      cubit = createCubit(token: tokenJson);
      cubit.onCardValidInput(true);
      cubit.createCharge();
      cubit.onCardValidInput(false);
      expect(cubit.state.status, CardPaymentStatus.tokenizing);
    });

    test('createCharge with null token does not call repository', () async {
      cubit = createCubit(token: null);
      cubit.onCardValidInput(true);
      await cubit.createCharge();
      expect(repository.chargeCallCount, 0);
      expect(cubit.state.status, CardPaymentStatus.tokenizationFailed);
    });

    test('createCharge with empty token does not call repository', () async {
      cubit = createCubit(token: '');
      cubit.onCardValidInput(true);
      await cubit.createCharge();
      expect(repository.chargeCallCount, 0);
      expect(cubit.state.status, CardPaymentStatus.tokenizationFailed);
    });

    test('createCharge with valid token passes sourceToken to repository', () async {
      cubit = createCubit(token: '{"id":"tok_abc"}');
      cubit.onCardValidInput(true);
      await cubit.createCharge();
      expect(repository.chargeCallCount, 1);
      expect(repository.lastSourceToken, '{"id":"tok_abc"}');
      expect(repository.lastOrderId, orderId);
      expect(repository.lastIdempotencyKey, orderId);
    });

    test('createCharge with invalid card status does not call repository', () async {
      cubit = createCubit(token: tokenJson);
      cubit.onCardValidInput(false);
      await cubit.createCharge();
      expect(repository.chargeCallCount, 0);
    });

    test('createCharge error transitions to paymentFailed', () async {
      cubit = createCubit(token: tokenJson, chargeError: Exception('network'));
      cubit.onCardValidInput(true);
      await cubit.createCharge();
      expect(cubit.state.status, CardPaymentStatus.paymentFailed);
    });

    test('createCharge success transitions to chargeCreated with transactionUrl', () async {
      cubit = createCubit(token: tokenJson);
      cubit.onCardValidInput(true);
      await cubit.createCharge();
      expect(cubit.state.status, CardPaymentStatus.chargeCreated);
      expect(cubit.state.chargeId, chargeId);
      expect(cubit.state.transactionUrl, 'https://tap.company/3ds');
    });

    test('verifyCharge with verified result returns succeeded', () async {
      cubit = createCubit(token: tokenJson);
      cubit.onCardValidInput(true);
      await cubit.createCharge();
      final result = await cubit.verifyCharge();
      expect(result, 'succeeded');
      expect(cubit.state.status, CardPaymentStatus.paymentSucceeded);
    });

    test('verifyCharge with pending result returns pending', () async {
      repository = _FakeRepository(
        chargeResult: TapChargeResult(
          chargeId: chargeId,
          status: 'INITIATED',
          transactionUrl: 'https://tap.company/3ds',
        ),
        verifyResult: TapVerificationResult(
          chargeId: chargeId,
          status: 'PENDING',
          verified: false,
          orderPaymentStatus: 'pending',
        ),
      );
      cubit = CardPaymentCubit(repository: repository, sourceTokenProvider: () async => tokenJson)..start(orderId: orderId);
      cubit.onCardValidInput(true);
      await cubit.createCharge();
      final result = await cubit.verifyCharge();
      expect(result, 'pending');
      expect(cubit.state.status, CardPaymentStatus.paymentPending);
    });

    test('verifyCharge with failed result returns failed', () async {
      repository = _FakeRepository(
        chargeResult: TapChargeResult(
          chargeId: chargeId,
          status: 'INITIATED',
          transactionUrl: 'https://tap.company/3ds',
        ),
        verifyResult: TapVerificationResult(
          chargeId: chargeId,
          status: 'FAILED',
          verified: false,
          orderPaymentStatus: 'failed',
        ),
      );
      cubit = CardPaymentCubit(repository: repository, sourceTokenProvider: () async => tokenJson)..start(orderId: orderId);
      cubit.onCardValidInput(true);
      await cubit.createCharge();
      final result = await cubit.verifyCharge();
      expect(result, 'failed');
      expect(cubit.state.status, CardPaymentStatus.paymentFailed);
    });

    test('verifyCharge with null chargeId returns null', () async {
      cubit = createCubit(token: tokenJson);
      final result = await cubit.verifyCharge();
      expect(result, isNull);
      expect(repository.verifyCallCount, 0);
    });

    test('verifyCharge error returns failed', () async {
      cubit = createCubit(token: tokenJson, verifyError: Exception('timeout'));
      cubit.onCardValidInput(true);
      await cubit.createCharge();
      final result = await cubit.verifyCharge();
      expect(result, 'failed');
      expect(cubit.state.status, CardPaymentStatus.paymentFailed);
    });

    test('extractTokenId extracts id from valid JSON', () {
      cubit = createCubit(token: tokenJson);
      final id = cubit.extractTokenId(tokenJson);
      expect(id, 'tok_test_123');
    });

    test('extractTokenId returns empty for invalid JSON', () {
      cubit = createCubit(token: tokenJson);
      final id = cubit.extractTokenId('not json');
      expect(id, '');
    });

    test('extractTokenId returns empty for JSON without id', () {
      cubit = createCubit(token: tokenJson);
      final id = cubit.extractTokenId('{"foo":"bar"}');
      expect(id, '');
    });

    test('concurrent createCharge calls are guarded', () async {
      cubit = createCubit(token: tokenJson);
      cubit.onCardValidInput(true);
      final f1 = cubit.createCharge();
      final f2 = cubit.createCharge();
      await Future.wait([f1, f2]);
      expect(repository.chargeCallCount, 1);
    });

    test('state copyWith clears error correctly', () {
      cubit = createCubit(token: tokenJson);
      cubit.onCardValidInput(true);
      cubit.createCharge();
      final state = cubit.state.copyWith(status: CardPaymentStatus.initial);
      expect(state.status, CardPaymentStatus.initial);
      expect(state.errorMessage, isNull);
    });
  });
}
