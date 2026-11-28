class PaymentChargeResult {
  const PaymentChargeResult({
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

  factory PaymentChargeResult.fromMap(Map<String, dynamic> json) {
    return PaymentChargeResult(
      chargeId: (json['chargeId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      transactionUrl: json['transactionUrl']?.toString(),
      requiresRedirect: json['requiresRedirect'] == true,
      reused: json['reused'] == true,
    );
  }
}

class PaymentVerificationResult {
  const PaymentVerificationResult({
    required this.chargeId,
    required this.status,
    required this.verified,
    required this.orderPaymentStatus,
    this.savedCardStatus,
    this.finalizedOrder,
  });

  final String chargeId;
  final String status;
  final bool verified;
  final String orderPaymentStatus;
  final String? savedCardStatus;
  final Map<String, dynamic>? finalizedOrder;

  factory PaymentVerificationResult.fromMap(Map<String, dynamic> json) {
    return PaymentVerificationResult(
      chargeId: (json['chargeId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      verified: json['verified'] == true,
      orderPaymentStatus: (json['orderPaymentStatus'] ?? '').toString(),
      finalizedOrder: json['finalizedOrder'] is Map
          ? Map<String, dynamic>.from(json['finalizedOrder'] as Map)
          : null,
    );
  }
}

abstract class PaymentRepository {
  Future<PaymentVerificationResult> verifyCharge(String chargeId);
}
