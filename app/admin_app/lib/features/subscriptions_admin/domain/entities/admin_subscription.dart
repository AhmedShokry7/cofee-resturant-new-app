import 'dart:math' as math;

import 'package:admin_app/core/locale/app_locale.dart';

class AdminSubscription {
  const AdminSubscription({
    required this.id,
    this.userId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.planId,
    this.planCode,
    this.planNameAr,
    this.planNameEn,
    this.planPrice,
    this.currencyCode,
    this.planDurationDays,
    required this.status,
    this.startsAt,
    this.endsAt,
    this.bonusExpiresAt,
    this.cupsEntitled = 0,
    this.cupsUsed = 0,
    this.cupsCarriedOver = 0,
    this.cupsReserved = 0,
    this.bonusBalance = 0,
    this.autoRenew = false,
    this.paymentReference,
    this.createdAt,
    this.usageCount = 0,
    this.lastUsedAt,
  });

  final String id;
  final String? userId;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? planId;
  final String? planCode;
  final String? planNameAr;
  final String? planNameEn;
  final double? planPrice;
  final String? currencyCode;
  final int? planDurationDays;

  /// The effective status: an active record whose period has passed is shown
  /// as expired even before the hourly expiry job touches it.
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? bonusExpiresAt;
  final int cupsEntitled;
  final int cupsUsed;
  final int cupsCarriedOver;
  final int cupsReserved;
  final double bonusBalance;
  final bool autoRenew;
  final String? paymentReference;
  final DateTime? createdAt;
  final int usageCount;
  final DateTime? lastUsedAt;

  bool get isActive => status == 'active';
  bool get isPendingPayment => status == 'pending_payment';
  bool get isExpired => status == 'expired';
  bool get isCancelled => status == 'cancelled';

  int get cupsTotal => cupsEntitled + cupsCarriedOver;

  int get cupsAvailable => math.max(cupsTotal - cupsUsed - cupsReserved, 0);

  double get cupsProgress {
    if (cupsTotal <= 0) return 0;
    return (cupsUsed / cupsTotal).clamp(0.0, 1.0).toDouble();
  }

  /// A subscription whose paid period ends within the next seven days.
  bool get isExpiringSoon {
    if (!isActive) return false;
    final end = endsAt;
    if (end == null) return false;
    final left = end.difference(DateTime.now());
    return !left.isNegative && left <= const Duration(days: 7);
  }

  /// Whole days left in the paid period, or null when it never started.
  int? get daysRemaining {
    final end = endsAt;
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    if (left.isNegative) return 0;
    return left.inHours < 24 ? 1 : (left.inHours / 24).ceil();
  }

  bool get isCancellable => (isActive || isPendingPayment) && cupsReserved <= 0;

  String planNameFor(AppLanguage language) {
    final name = language.isArabic ? planNameAr?.trim() : planNameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic
        ? planNameEn?.trim()
        : planNameAr?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return planCode?.trim() ?? '';
  }

  factory AdminSubscription.fromJson(Map<String, dynamic> json) {
    return AdminSubscription(
      id: '${json['id'] ?? ''}',
      userId: json['user_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      customerPhone: json['customer_phone'] as String?,
      planId: json['plan_id'] as String?,
      planCode: json['plan_code'] as String?,
      planNameAr: json['plan_name_ar'] as String?,
      planNameEn: json['plan_name_en'] as String?,
      planPrice: (json['plan_price'] as num?)?.toDouble(),
      currencyCode: json['currency_code'] as String?,
      planDurationDays: (json['plan_duration_days'] as num?)?.toInt(),
      status: '${json['status'] ?? ''}',
      startsAt: _toDateTime(json['starts_at']),
      endsAt: _toDateTime(json['ends_at']),
      bonusExpiresAt: _toDateTime(json['bonus_expires_at']),
      cupsEntitled: (json['cups_entitled'] as num?)?.toInt() ?? 0,
      cupsUsed: (json['cups_used'] as num?)?.toInt() ?? 0,
      cupsCarriedOver: (json['cups_carried_over'] as num?)?.toInt() ?? 0,
      cupsReserved: (json['cups_reserved'] as num?)?.toInt() ?? 0,
      bonusBalance: (json['bonus_balance'] as num?)?.toDouble() ?? 0,
      autoRenew: json['auto_renew'] == true,
      paymentReference: json['payment_reference'] as String?,
      createdAt: _toDateTime(json['created_at']),
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      lastUsedAt: _toDateTime(json['last_used_at']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
