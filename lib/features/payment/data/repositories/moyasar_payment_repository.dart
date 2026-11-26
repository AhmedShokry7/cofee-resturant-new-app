import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MoyasarPaymentIntent {
  const MoyasarPaymentIntent({
    required this.paymentId,
    required this.amount,
    required this.currency,
    required this.description,
  });

  final String paymentId;
  final int amount;
  final String currency;
  final String description;

  factory MoyasarPaymentIntent.fromJson(Map<String, dynamic> json) =>
      MoyasarPaymentIntent(
        paymentId: (json['paymentId'] ?? '').toString(),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        currency: (json['currency'] ?? 'SAR').toString(),
        description: (json['description'] ?? '').toString(),
      );
}

abstract interface class MoyasarPaymentOperations {
  Future<MoyasarPaymentIntent> preparePayment({
    String? orderId,
    String? subscriptionId,
  });
}

class SupabaseMoyasarPaymentRepository extends SupabaseTapPaymentRepository
    implements MoyasarPaymentOperations {
  SupabaseMoyasarPaymentRepository({super.client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  @override
  Future<MoyasarPaymentIntent> preparePayment({
    String? orderId,
    String? subscriptionId,
  }) async {
    final response = await _client.functions.invoke(
      'moyasar-prepare-payment',
      body: {
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        if (subscriptionId != null && subscriptionId.isNotEmpty)
          'subscriptionId': subscriptionId,
      },
    );
    if (response.data is! Map<String, dynamic>) {
      throw StateError('Invalid Moyasar payment preparation response');
    }
    return MoyasarPaymentIntent.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<TapVerificationResult> verifyCharge(String chargeId) async {
    final response = await _client.functions.invoke(
      'moyasar-verify-payment',
      body: {'paymentId': chargeId},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid Moyasar payment verification response');
    }
    return TapVerificationResult(
      chargeId: (data['paymentId'] ?? chargeId).toString(),
      status: (data['status'] ?? '').toString(),
      verified: data['verified'] == true,
      orderPaymentStatus: (data['orderPaymentStatus'] ?? '').toString(),
    );
  }
}
