import 'package:admin_app/core/locale/app_locale.dart';

class AdminSubscriptionCustomer {
  const AdminSubscriptionCustomer({
    required this.id,
    this.fullName = '',
    this.email,
    this.phone,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? phone;

  String displayName(AppLanguage language) {
    final name = fullName.trim();
    if (name.isNotEmpty) return name;
    final contact = (phone ?? '').trim();
    if (contact.isNotEmpty) return contact;
    return (email ?? '').trim().isEmpty ? id : email!.trim();
  }

  factory AdminSubscriptionCustomer.fromJson(Map<String, dynamic> json) =>
      AdminSubscriptionCustomer(
        id: '${json['id'] ?? ''}',
        fullName: '${json['full_name'] ?? ''}',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
      );
}

class AdminSubscriptionPaymentMethod {
  const AdminSubscriptionPaymentMethod({
    required this.id,
    this.code = '',
    this.nameAr = '',
    this.nameEn = '',
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    return primary.trim().isNotEmpty ? primary.trim() : fallback.trim();
  }

  factory AdminSubscriptionPaymentMethod.fromJson(Map<String, dynamic> json) =>
      AdminSubscriptionPaymentMethod(
        id: '${json['id'] ?? ''}',
        code: '${json['code'] ?? ''}',
        nameAr: '${json['name_ar'] ?? ''}',
        nameEn: '${json['name_en'] ?? ''}',
      );
}

enum AdminCreateSubscriptionOutcome {
  created,
  invalid,
  customerUnavailable,
  planUnavailable,
  paymentMethodRequired,
  paymentMethodUnavailable,
  paymentConfirmationRequired,
  databaseNeedsUpdate,
  idempotencyConflict,
  failed,
}
