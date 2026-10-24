import 'package:admin_app/core/locale/app_locale.dart';

class AdminSubscription {
  const AdminSubscription({
    required this.id,
    this.userId,
    this.customerName,
    this.customerEmail,
    this.planId,
    this.planNameAr,
    this.planNameEn,
    this.planPrice,
    this.currencyCode,
    required this.status,
    this.startsAt,
    this.endsAt,
    this.cupsEntitled = 0,
    this.cupsUsed = 0,
    this.cupsCarriedOver = 0,
    this.cupsReserved = 0,
    this.bonusBalance = 0,
    this.autoRenew = false,
    this.paymentReference,
    this.createdAt,
  });

  final String id;
  final String? userId;
  final String? customerName;
  final String? customerEmail;
  final String? planId;
  final String? planNameAr;
  final String? planNameEn;
  final double? planPrice;
  final String? currencyCode;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int cupsEntitled;
  final int cupsUsed;
  final int cupsCarriedOver;
  final int cupsReserved;
  final double bonusBalance;
  final bool autoRenew;
  final String? paymentReference;
  final DateTime? createdAt;

  String planNameFor(AppLanguage language) {
    if (language.isArabic) return planNameAr?.trim() ?? '';
    return planNameEn?.trim() ?? '';
  }

  factory AdminSubscription.fromJson(Map<String, dynamic> json) {
    return AdminSubscription(
      id: '${json['id'] ?? ''}',
      userId: json['user_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      planId: json['plan_id'] as String?,
      planNameAr: json['plan_name_ar'] as String?,
      planNameEn: json['plan_name_en'] as String?,
      planPrice: (json['plan_price'] as num?)?.toDouble(),
      currencyCode: json['currency_code'] as String?,
      status: '${json['status'] ?? ''}',
      startsAt: _toDateTime(json['starts_at']),
      endsAt: _toDateTime(json['ends_at']),
      cupsEntitled: (json['cups_entitled'] as num?)?.toInt() ?? 0,
      cupsUsed: (json['cups_used'] as num?)?.toInt() ?? 0,
      cupsCarriedOver: (json['cups_carried_over'] as num?)?.toInt() ?? 0,
      cupsReserved: (json['cups_reserved'] as num?)?.toInt() ?? 0,
      bonusBalance: (json['bonus_balance'] as num?)?.toDouble() ?? 0,
      autoRenew: json['auto_renew'] == true,
      paymentReference: json['payment_reference'] as String?,
      createdAt: _toDateTime(json['created_at']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
