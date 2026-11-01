import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TapChargeResult {
  const TapChargeResult({
    required this.chargeId,
    required this.status,
    this.transactionUrl,
    this.requiresRedirect = false,
    this.reused = false,
  });

  final String chargeId;
  final String status;
  final String? transactionUrl;
  final bool requiresRedirect;
  final bool reused;

  factory TapChargeResult.fromMap(Map<String, dynamic> json) {
    return TapChargeResult(
      chargeId: (json['chargeId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      transactionUrl: json['transactionUrl']?.toString(),
      requiresRedirect: json['requiresRedirect'] == true,
      reused: json['reused'] == true,
    );
  }
}

class TapVerificationResult {
  const TapVerificationResult({
    required this.chargeId,
    required this.status,
    required this.verified,
    required this.orderPaymentStatus,
  });

  final String chargeId;
  final String status;
  final bool verified;
  final String orderPaymentStatus;

  factory TapVerificationResult.fromMap(Map<String, dynamic> json) {
    return TapVerificationResult(
      chargeId: (json['chargeId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      verified: json['verified'] == true,
      orderPaymentStatus: (json['orderPaymentStatus'] ?? '').toString(),
    );
  }
}

abstract class TapPaymentRepository {
  Future<TapChargeResult> createCharge({
    required String orderId,
    required String idempotencyKey,
    bool saveCard = false,
    String? savedCardId,
    String? sourceToken,
  });

  Future<TapChargeResult> createSubscriptionCharge({
    required String subscriptionId,
    required String idempotencyKey,
    bool saveCard = false,
    String? savedCardId,
    String? sourceToken,
  });

  Future<TapVerificationResult> verifyCharge(String chargeId);
}

class SupabaseTapPaymentRepository implements TapPaymentRepository {
  SupabaseTapPaymentRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  @override
  Future<TapChargeResult> createCharge({
    required String orderId,
    required String idempotencyKey,
    bool saveCard = false,
    String? savedCardId,
    String? sourceToken,
  }) async {
    final response = await _client.functions.invoke(
      'tap-create-charge',
      body: {
        'orderId': orderId,
        'idempotencyKey': idempotencyKey,
        'saveCard': saveCard,
        if (savedCardId != null && savedCardId.isNotEmpty)
          'savedCardId': savedCardId,
        if (sourceToken != null && sourceToken.isNotEmpty)
          'sourceToken': sourceToken,
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid create charge response');
    }
    return TapChargeResult.fromMap(data);
  }

  @override
  Future<TapChargeResult> createSubscriptionCharge({
    required String subscriptionId,
    required String idempotencyKey,
    bool saveCard = false,
    String? savedCardId,
    String? sourceToken,
  }) async {
    final response = await _client.functions.invoke(
      'tap-create-charge',
      body: {
        'subscriptionId': subscriptionId,
        'idempotencyKey': idempotencyKey,
        'saveCard': saveCard,
        if (savedCardId != null && savedCardId.isNotEmpty)
          'savedCardId': savedCardId,
        if (sourceToken != null && sourceToken.isNotEmpty)
          'sourceToken': sourceToken,
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid create charge response');
    }
    return TapChargeResult.fromMap(data);
  }

  @override
  Future<TapVerificationResult> verifyCharge(String chargeId) async {
    final response = await _client.functions.invoke(
      'tap-verify-charge',
      body: {'chargeId': chargeId},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid verify charge response');
    }
    return TapVerificationResult.fromMap(data);
  }
}
