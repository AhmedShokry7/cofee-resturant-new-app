import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/subscription_plans_admin/data/models/admin_subscription_plan_product.dart';

/// One row of `subscriptions.plans` with its demand figures.
class AdminSubscriptionPlan {
  const AdminSubscriptionPlan({
    required this.id,
    this.code = '',
    this.nameAr,
    this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    this.price = 0,
    this.currencyCode = 'SAR',
    this.durationDays = 0,
    this.cupsPerCycle = 0,
    this.bonusType = 'none',
    this.bonusValue = 0,
    this.bonusExpiresWithCycle = true,
    this.rolloverCapCups = 0,
    this.renewalPolicy = 'manual',
    this.autoRenewSupported = false,
    this.allBranches = true,
    this.productScope = 'all',
    this.products = const <AdminSubscriptionPlanProduct>[],
    this.isActive = true,
    this.isForSale = true,
    this.subscribersCount = 0,
    this.activeSubscribers = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String code;
  final String? nameAr;
  final String? nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final double price;
  final String currencyCode;
  final int durationDays;
  final int cupsPerCycle;
  final String bonusType;
  final double bonusValue;
  final bool bonusExpiresWithCycle;
  final int rolloverCapCups;
  final String renewalPolicy;
  final bool autoRenewSupported;
  final bool allBranches;
  final String productScope;
  final List<AdminSubscriptionPlanProduct> products;
  final bool isActive;
  final bool isForSale;
  final int subscribersCount;
  final int activeSubscribers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// A plan customers can find in `subscriptions.list_plans`.
  bool get isOnSale => isActive && isForSale;

  bool get isPaused => !isActive;

  bool get isAutoRenew => renewalPolicy == 'auto' && autoRenewSupported;

  String nameFor(AppLanguage language) {
    final name = language.isArabic ? nameAr?.trim() : nameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic ? nameEn?.trim() : nameAr?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return code;
  }

  String? descriptionFor(AppLanguage language) {
    final description = language.isArabic
        ? descriptionAr?.trim()
        : descriptionEn?.trim();
    if (description != null && description.isNotEmpty) return description;
    final fallback = language.isArabic
        ? descriptionEn?.trim()
        : descriptionAr?.trim();
    return fallback == null || fallback.isEmpty ? null : fallback;
  }

  factory AdminSubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionPlan(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      nameAr: json['name_ar'] as String?,
      nameEn: json['name_en'] as String?,
      descriptionAr: json['description_ar'] as String?,
      descriptionEn: json['description_en'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currencyCode: '${json['currency_code'] ?? 'SAR'}',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      cupsPerCycle: (json['cups_per_cycle'] as num?)?.toInt() ?? 0,
      bonusType: '${json['bonus_type'] ?? 'none'}',
      bonusValue: (json['bonus_value'] as num?)?.toDouble() ?? 0,
      bonusExpiresWithCycle: json['bonus_expires_with_cycle'] != false,
      rolloverCapCups: (json['rollover_cap_cups'] as num?)?.toInt() ?? 0,
      renewalPolicy: '${json['renewal_policy'] ?? 'manual'}',
      autoRenewSupported: json['auto_renew_supported'] == true,
      allBranches: json['all_branches'] != false,
      productScope: '${json['product_scope'] ?? 'all'}',
      products: _toProducts(json['products']),
      isActive: json['is_active'] != false,
      isForSale: json['is_for_sale'] != false,
      subscribersCount: (json['subscribers_count'] as num?)?.toInt() ?? 0,
      activeSubscribers: (json['active_subscribers'] as num?)?.toInt() ?? 0,
      createdAt: _toDateTime(json['created_at']),
      updatedAt: _toDateTime(json['updated_at']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }

  static List<AdminSubscriptionPlanProduct> _toProducts(Object? value) {
    if (value is! List) return const <AdminSubscriptionPlanProduct>[];
    return value
        .whereType<Map>()
        .map(
          (row) => AdminSubscriptionPlanProduct.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }
}

/// The editable fields of a plan, sent to `admin_save_subscription_plan`.
class AdminSubscriptionPlanDraft {
  const AdminSubscriptionPlanDraft({
    this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.price,
    required this.currencyCode,
    required this.durationDays,
    required this.cupsPerCycle,
    required this.bonusType,
    required this.bonusValue,
    required this.bonusExpiresWithCycle,
    required this.rolloverCapCups,
    required this.renewalPolicy,
    required this.autoRenewSupported,
    this.productScope = 'all',
    this.productIds = const <String>[],
    required this.isActive,
    required this.isForSale,
  });

  final String? id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final double price;
  final String currencyCode;
  final int durationDays;
  final int cupsPerCycle;
  final String bonusType;
  final double bonusValue;
  final bool bonusExpiresWithCycle;
  final int rolloverCapCups;
  final String renewalPolicy;
  final bool autoRenewSupported;
  final String productScope;
  final List<String> productIds;
  final bool isActive;
  final bool isForSale;

  factory AdminSubscriptionPlanDraft.fromPlan(AdminSubscriptionPlan plan) {
    return AdminSubscriptionPlanDraft(
      id: plan.id,
      code: plan.code,
      nameAr: plan.nameAr ?? '',
      nameEn: plan.nameEn ?? '',
      descriptionAr: plan.descriptionAr,
      descriptionEn: plan.descriptionEn,
      price: plan.price,
      currencyCode: plan.currencyCode,
      durationDays: plan.durationDays,
      cupsPerCycle: plan.cupsPerCycle,
      bonusType: plan.bonusType,
      bonusValue: plan.bonusValue,
      bonusExpiresWithCycle: plan.bonusExpiresWithCycle,
      rolloverCapCups: plan.rolloverCapCups,
      renewalPolicy: plan.renewalPolicy,
      autoRenewSupported: plan.autoRenewSupported,
      productScope: plan.productScope,
      productIds: plan.products
          .map((product) => product.id)
          .toList(growable: false),
      isActive: plan.isActive,
      isForSale: plan.isForSale,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'code': code,
      'name_ar': nameAr,
      'name_en': nameEn,
      'price': price,
      'currency_code': currencyCode,
      'duration_days': durationDays,
      'cups_per_cycle': cupsPerCycle,
      'bonus_type': bonusType,
      'bonus_value': bonusValue,
      'bonus_expires_with_cycle': bonusExpiresWithCycle,
      'rollover_cap_cups': rolloverCapCups,
      'renewal_policy': renewalPolicy,
      'auto_renew_supported': autoRenewSupported,
      'product_scope': productScope,
      'product_ids': productIds,
      'is_active': isActive,
      'is_for_sale': isForSale,
    };
    final planId = id;
    if (planId != null && planId.isNotEmpty) data['id'] = planId;
    final arabicDescription = descriptionAr?.trim();
    if (arabicDescription != null && arabicDescription.isNotEmpty) {
      data['description_ar'] = arabicDescription;
    }
    final englishDescription = descriptionEn?.trim();
    if (englishDescription != null && englishDescription.isNotEmpty) {
      data['description_en'] = englishDescription;
    }
    return data;
  }
}
