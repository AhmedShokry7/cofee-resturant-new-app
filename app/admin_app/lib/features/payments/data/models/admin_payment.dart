class AdminPayment {
  const AdminPayment({
    required this.id,
    this.orderId,
    this.orderNumber,
    this.customerName,
    required this.provider,
    this.providerReference,
    required this.amount,
    required this.currencyCode,
    required this.status,
    this.paidAt,
    this.refundedAt,
    this.cardBrand,
    this.cardLast4,
    this.cardHolderName,
    this.verifiedByServer = false,
    this.createdAt,
  });

  final String id;
  final String? orderId;
  final String? orderNumber;
  final String? customerName;
  final String provider;
  final String? providerReference;
  final double amount;
  final String currencyCode;
  final String status;
  final DateTime? paidAt;
  final DateTime? refundedAt;
  final String? cardBrand;
  final String? cardLast4;
  final String? cardHolderName;
  final bool verifiedByServer;
  final DateTime? createdAt;

  factory AdminPayment.fromJson(Map<String, dynamic> json) {
    return AdminPayment(
      id: '${json['id'] ?? ''}',
      orderId: json['order_id'] as String?,
      orderNumber: json['order_number'] as String?,
      customerName: json['customer_name'] as String?,
      provider: '${json['provider'] ?? ''}',
      providerReference: json['provider_reference'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currencyCode: '${json['currency_code'] ?? 'SAR'}',
      status: '${json['status'] ?? ''}',
      paidAt: _toDateTime(json['paid_at']),
      refundedAt: _toDateTime(json['refunded_at']),
      cardBrand: json['card_brand'] as String?,
      cardLast4: json['card_last4'] as String?,
      cardHolderName: json['card_holder_name'] as String?,
      verifiedByServer: json['verified_by_server'] == true,
      createdAt: _toDateTime(json['created_at']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
