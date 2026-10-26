import 'package:admin_app/core/locale/app_locale.dart';

/// One redeemed subscription cup from `subscriptions.subscription_usage`.
class AdminSubscriptionUsage {
  const AdminSubscriptionUsage({
    required this.id,
    this.quantity = 0,
    this.method = '',
    this.createdAt,
    this.branchNameAr,
    this.branchNameEn,
    this.productNameAr,
    this.productNameEn,
    this.orderId,
    this.orderNumber,
  });

  final String id;
  final int quantity;
  final String method;
  final DateTime? createdAt;
  final String? branchNameAr;
  final String? branchNameEn;
  final String? productNameAr;
  final String? productNameEn;
  final String? orderId;
  final String? orderNumber;

  String branchNameFor(AppLanguage language) => language.isArabic
      ? (branchNameAr?.trim() ?? '')
      : (branchNameEn?.trim() ?? '');

  String productNameFor(AppLanguage language) => language.isArabic
      ? (productNameAr?.trim() ?? '')
      : (productNameEn?.trim() ?? '');

  factory AdminSubscriptionUsage.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionUsage(
      id: '${json['id'] ?? ''}',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      method: '${json['method'] ?? ''}',
      createdAt: _toDateTime(json['created_at']),
      branchNameAr: json['branch_name_ar'] as String?,
      branchNameEn: json['branch_name_en'] as String?,
      productNameAr: json['product_name_ar'] as String?,
      productNameEn: json['product_name_en'] as String?,
      orderId: json['order_id'] as String?,
      orderNumber: json['order_number'] as String?,
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
