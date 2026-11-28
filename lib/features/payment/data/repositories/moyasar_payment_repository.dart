import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/payment/data/repositories/payment_repository.dart';
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
    Map<String, dynamic>? checkoutDraft,
  });

  Future<PaymentChargeResult> createSavedCardCharge({
    String? orderId,
    String? subscriptionId,
    Map<String, dynamic>? checkoutDraft,
    required String savedCardId,
  });
}

class SupabaseMoyasarPaymentRepository
    implements PaymentRepository, MoyasarPaymentOperations {
  SupabaseMoyasarPaymentRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  @override
  Future<MoyasarPaymentIntent> preparePayment({
    String? orderId,
    String? subscriptionId,
    Map<String, dynamic>? checkoutDraft,
  }) async {
    final response = await _client.functions.invoke(
      'moyasar-prepare-payment',
      body: {
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        if (subscriptionId != null && subscriptionId.isNotEmpty)
          'subscriptionId': subscriptionId,
        if (checkoutDraft != null) 'checkout': checkoutDraft,
      },
    );
    if (response.data is! Map<String, dynamic>) {
      throw StateError('Invalid Moyasar payment preparation response');
    }
    return MoyasarPaymentIntent.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PaymentChargeResult> createSavedCardCharge({
    String? orderId,
    String? subscriptionId,
    Map<String, dynamic>? checkoutDraft,
    required String savedCardId,
  }) async {
    final response = await _client.functions.invoke(
      'moyasar-charge-saved-card',
      body: {
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        if (subscriptionId != null && subscriptionId.isNotEmpty)
          'subscriptionId': subscriptionId,
        if (checkoutDraft != null) 'checkout': checkoutDraft,
        'savedCardId': savedCardId,
      },
    );
    if (response.data is! Map<String, dynamic>) {
      throw StateError('Invalid Moyasar saved-card response');
    }
    return PaymentChargeResult.fromMap(response.data as Map<String, dynamic>);
  }

  @override
  Future<PaymentVerificationResult> verifyCharge(String chargeId) async {
    final response = await _client.functions.invoke(
      'moyasar-verify-payment',
      body: {'paymentId': chargeId},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid Moyasar payment verification response');
    }
    return PaymentVerificationResult(
      chargeId: (data['paymentId'] ?? chargeId).toString(),
      status: (data['status'] ?? '').toString(),
      verified: data['verified'] == true,
      orderPaymentStatus: (data['orderPaymentStatus'] ?? '').toString(),
      savedCardStatus: data['savedCardStatus']?.toString(),
      finalizedOrder: data['finalizedOrder'] is Map
          ? Map<String, dynamic>.from(data['finalizedOrder'] as Map)
          : null,
    );
  }
}
