import 'package:admin_app/core/locale/app_locale.dart';

/// Subscription balance reserved for an order, supplied by `admin_orders()`.
class AdminSubscriptionPreorder {
  const AdminSubscriptionPreorder({
    required this.subscriptionId,
    required this.planNameAr,
    required this.planNameEn,
    required this.reservedQuantity,
    required this.consumptionStatus,
  });

  final String subscriptionId;
  final String planNameAr;
  final String planNameEn;
  final int reservedQuantity;
  final String consumptionStatus;

  String planNameFor(AppLanguage language) {
    final preferred = language.isArabic ? planNameAr : planNameEn;
    final fallback = language.isArabic ? planNameEn : planNameAr;
    if (preferred.trim().isNotEmpty) return preferred.trim();
    if (fallback.trim().isNotEmpty) return fallback.trim();
    return subscriptionId;
  }

  factory AdminSubscriptionPreorder.fromJson(Map<String, dynamic> json) =>
      AdminSubscriptionPreorder(
        subscriptionId: '${json['subscription_id'] ?? ''}',
        planNameAr: '${json['plan_name_ar'] ?? ''}',
        planNameEn: '${json['plan_name_en'] ?? ''}',
        reservedQuantity: (json['reserved_quantity'] as num?)?.toInt() ?? 0,
        consumptionStatus: '${json['consumption_status'] ?? 'reserved'}',
      );
}
