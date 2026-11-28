import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/payment/data/repositories/moyasar_payment_repository.dart';
import 'package:new_coffee/features/payment/data/repositories/payment_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_state.dart';

class _Payments implements PaymentRepository, MoyasarPaymentOperations {
  int prepareCalls = 0;
  int savedCardCalls = 0;
  int verifyCalls = 0;
  String? savedCardId;
  PaymentVerificationResult verification = const PaymentVerificationResult(
    chargeId: 'pay_123',
    status: 'paid',
    verified: true,
    orderPaymentStatus: 'paid',
  );
  Completer<PaymentChargeResult>? savedCardGate;

  @override
  Future<MoyasarPaymentIntent> preparePayment({
    String? orderId,
    String? subscriptionId,
    Map<String, dynamic>? checkoutDraft,
  }) async {
    prepareCalls++;
    return const MoyasarPaymentIntent(
      paymentId: 'pay_123',
      amount: 1045,
      currency: 'SAR',
      description: 'Order',
    );
  }

  @override
  Future<PaymentChargeResult> createSavedCardCharge({
    String? orderId,
    String? subscriptionId,
    Map<String, dynamic>? checkoutDraft,
    required String savedCardId,
  }) async {
    savedCardCalls++;
    this.savedCardId = savedCardId;
    return savedCardGate?.future ??
        const PaymentChargeResult(chargeId: 'pay_123', status: 'initiated');
  }

  @override
  Future<PaymentVerificationResult> verifyCharge(String chargeId) async {
    verifyCalls++;
    return verification;
  }
}

void main() {
  test('preparing a checkout does not report payment success', () async {
    final payments = _Payments();
    final cubit = CardPaymentCubit(repository: payments)
      ..start(checkoutDraft: {'idempotency_key': 'checkout-1'});
    addTearDown(cubit.close);

    await cubit.prepareMoyasarPayment();

    expect(payments.prepareCalls, 1);
    expect(payments.verifyCalls, 0);
    expect(cubit.state.status, CardPaymentStatus.chargeCreated);
    expect(cubit.state.chargeId, 'pay_123');
    expect(cubit.state.paymentAmountMinor, 1045);
  });

  test('only a server verified paid charge reports success', () async {
    final payments = _Payments();
    final cubit = CardPaymentCubit(repository: payments)..start(orderId: 'o1');
    addTearDown(cubit.close);
    await cubit.prepareMoyasarPayment();

    expect(await cubit.verifyCharge(), PaymentOutcome.succeeded);
    expect(cubit.state.status, CardPaymentStatus.paymentSucceeded);
  });

  test('unverified provider response cannot mark the order paid', () async {
    final payments = _Payments()
      ..verification = const PaymentVerificationResult(
        chargeId: 'pay_123',
        status: 'paid',
        verified: false,
        orderPaymentStatus: 'failed',
      );
    final cubit = CardPaymentCubit(repository: payments)..start(orderId: 'o1');
    addTearDown(cubit.close);
    await cubit.prepareMoyasarPayment();

    expect(await cubit.verifyCharge(), PaymentOutcome.failed);
    expect(cubit.state.status, CardPaymentStatus.paymentFailed);
  });

  test('pending 3DS verification stays pending', () async {
    final payments = _Payments()
      ..verification = const PaymentVerificationResult(
        chargeId: 'pay_123',
        status: 'initiated',
        verified: false,
        orderPaymentStatus: 'pending',
      );
    final cubit = CardPaymentCubit(repository: payments)..start(orderId: 'o1');
    addTearDown(cubit.close);
    await cubit.prepareMoyasarPayment();

    expect(await cubit.verifyCharge(), PaymentOutcome.pending);
    expect(cubit.state.status, CardPaymentStatus.paymentPending);
  });

  test('a response for another payment is rejected', () async {
    final payments = _Payments()
      ..verification = const PaymentVerificationResult(
        chargeId: 'someone-elses-payment',
        status: 'paid',
        verified: true,
        orderPaymentStatus: 'paid',
      );
    final cubit = CardPaymentCubit(repository: payments)..start(orderId: 'o1');
    addTearDown(cubit.close);
    await cubit.prepareMoyasarPayment();

    expect(await cubit.verifyCharge(), PaymentOutcome.failed);
    expect(cubit.state.status, CardPaymentStatus.paymentFailed);
  });

  test('double tap charges a saved card once', () async {
    final payments = _Payments()
      ..savedCardGate = Completer<PaymentChargeResult>();
    final cubit = CardPaymentCubit(repository: payments)
      ..start(orderId: 'o1', savedCardId: 'card-1');
    addTearDown(cubit.close);

    final first = cubit.chargeSavedCard();
    await cubit.chargeSavedCard();
    expect(payments.savedCardCalls, 1);
    expect(payments.savedCardId, 'card-1');

    payments.savedCardGate!.complete(
      const PaymentChargeResult(chargeId: 'pay_123', status: 'initiated'),
    );
    await first;
    expect(cubit.state.status, CardPaymentStatus.chargeCreated);
  });
}
