import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/coupons/domain/entities/coupon_json.dart';

enum AdminCouponDiscountType {
  percentage,
  fixedAmount;

  String get wireValue => switch (this) {
    AdminCouponDiscountType.percentage => 'percentage',
    AdminCouponDiscountType.fixedAmount => 'fixed_amount',
  };

  static AdminCouponDiscountType fromWire(Object? value) => switch ('$value') {
    'fixed_amount' => AdminCouponDiscountType.fixedAmount,
    _ => AdminCouponDiscountType.percentage,
  };
}

enum AdminCouponScope {
  all,
  category,
  product;

  String get wireValue => switch (this) {
    AdminCouponScope.all => 'all',
    AdminCouponScope.category => 'category',
    AdminCouponScope.product => 'product',
  };

  static AdminCouponScope fromWire(Object? value) => switch ('$value') {
    'category' => AdminCouponScope.category,
    'product' => AdminCouponScope.product,
    _ => AdminCouponScope.all,
  };
}

/// The state the directory shows for a coupon.
///
/// Precedence: paused > expired > scheduled > exhausted > expiring soon >
/// active. The database metrics use the same order, so the cards and the
/// directory can never disagree.
enum AdminCouponStatus {
  active,
  expiringSoon,
  scheduled,
  exhausted,
  expired,
  paused,
}

class AdminCouponScopeRef {
  const AdminCouponScopeRef({
    required this.id,
    this.nameAr,
    this.nameEn,
    this.imageUrl,
  });

  final String id;
  final String? nameAr;
  final String? nameEn;
  final String? imageUrl;

  String nameFor(AppLanguage language) {
    final name = language.isArabic ? nameAr?.trim() : nameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic ? nameEn?.trim() : nameAr?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return id;
  }

  factory AdminCouponScopeRef.fromJson(Map<String, dynamic> json) =>
      AdminCouponScopeRef(
        id: '${json['id'] ?? ''}',
        nameAr: json['name_ar'] as String?,
        nameEn: json['name_en'] as String?,
        imageUrl: json['image_url'] as String?,
      );
}

class AdminCoupon {
  const AdminCoupon({
    required this.id,
    required this.code,
    required this.titleAr,
    required this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    this.discountType = AdminCouponDiscountType.percentage,
    this.discountValue = 0,
    this.maxDiscount,
    this.minOrderAmount = 0,
    this.scope = AdminCouponScope.all,
    this.usageLimit,
    this.perUserLimit = 1,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
    this.redemptionsCount = 0,
    this.uniqueCustomers = 0,
    this.discountGiven = 0,
    this.lastRedeemedAt,
    this.createdAt,
    this.updatedAt,
    this.categories = const <AdminCouponScopeRef>[],
    this.products = const <AdminCouponScopeRef>[],
  });

  final String id;
  final String code;
  final String titleAr;
  final String titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final AdminCouponDiscountType discountType;
  final double discountValue;
  final double? maxDiscount;
  final double minOrderAmount;
  final AdminCouponScope scope;

  /// null means an unlimited number of total redemptions.
  final int? usageLimit;
  final int perUserLimit;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;

  final int redemptionsCount;
  final int uniqueCustomers;
  final double discountGiven;
  final DateTime? lastRedeemedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final List<AdminCouponScopeRef> categories;
  final List<AdminCouponScopeRef> products;

  static const zero = AdminCoupon(id: '', code: '', titleAr: '', titleEn: '');

  static const _expiringWindow = Duration(days: 7);

  bool get isPercentage => discountType == AdminCouponDiscountType.percentage;
  bool get hasUnlimitedUsage => usageLimit == null;
  bool get hasMaxDiscount => isPercentage && maxDiscount != null;
  bool get wasRedeemed => redemptionsCount > 0;
  bool get isScoped => scope != AdminCouponScope.all;

  int get scopeTargetCount => switch (scope) {
    AdminCouponScope.category => categories.length,
    AdminCouponScope.product => products.length,
    AdminCouponScope.all => 0,
  };

  int? get remainingUses {
    final limit = usageLimit;
    if (limit == null) return null;
    final remaining = limit - redemptionsCount;
    return remaining < 0 ? 0 : remaining;
  }

  double? get usageProgress {
    final limit = usageLimit;
    if (limit == null || limit <= 0) return null;
    return (redemptionsCount / limit).clamp(0, 1);
  }

  AdminCouponStatus statusAt([DateTime? now]) {
    final moment = now ?? DateTime.now();
    if (!isActive) return AdminCouponStatus.paused;
    final end = endsAt;
    if (end != null && !end.isAfter(moment)) return AdminCouponStatus.expired;
    final start = startsAt;
    if (start != null && start.isAfter(moment)) {
      return AdminCouponStatus.scheduled;
    }
    if (usageLimit != null && redemptionsCount >= usageLimit!) {
      return AdminCouponStatus.exhausted;
    }
    if (end != null && end.difference(moment) <= _expiringWindow) {
      return AdminCouponStatus.expiringSoon;
    }
    return AdminCouponStatus.active;
  }

  bool get isRunning {
    final status = statusAt();
    return status == AdminCouponStatus.active ||
        status == AdminCouponStatus.expiringSoon;
  }

  bool get isExpiringSoon => statusAt() == AdminCouponStatus.expiringSoon;

  String titleFor(AppLanguage language) {
    final name = language.isArabic ? titleAr.trim() : titleEn.trim();
    if (name.isNotEmpty) return name;
    final fallback = language.isArabic ? titleEn.trim() : titleAr.trim();
    return fallback.isNotEmpty ? fallback : code;
  }

  String? descriptionFor(AppLanguage language) {
    final text = language.isArabic
        ? descriptionAr?.trim()
        : descriptionEn?.trim();
    if (text != null && text.isNotEmpty) return text;
    final fallback = language.isArabic
        ? descriptionEn?.trim()
        : descriptionAr?.trim();
    return fallback != null && fallback.isNotEmpty ? fallback : null;
  }

  factory AdminCoupon.fromJson(Map<String, dynamic> json) => AdminCoupon(
    id: '${json['id'] ?? ''}',
    code: '${json['code'] ?? ''}',
    titleAr: '${json['title_ar'] ?? ''}',
    titleEn: '${json['title_en'] ?? ''}',
    descriptionAr: json['description_ar'] as String?,
    descriptionEn: json['description_en'] as String?,
    discountType: AdminCouponDiscountType.fromWire(json['discount_type']),
    discountValue: couponDouble(json['discount_value']),
    maxDiscount: couponNullableDouble(json['max_discount']),
    minOrderAmount: couponDouble(json['min_order_amount']),
    scope: AdminCouponScope.fromWire(json['applies_to']),
    usageLimit: couponNullableInt(json['usage_limit']),
    perUserLimit: couponInt(json['per_user_limit']),
    startsAt: couponDate(json['starts_at']),
    endsAt: couponDate(json['ends_at']),
    isActive: json['is_active'] == true,
    redemptionsCount: couponInt(json['redemptions_count']),
    uniqueCustomers: couponInt(json['unique_customers']),
    discountGiven: couponDouble(json['discount_given']),
    lastRedeemedAt: couponDate(json['last_redeemed_at']),
    createdAt: couponDate(json['created_at']),
    updatedAt: couponDate(json['updated_at']),
    categories: _scopeRefs(json['categories']),
    products: _scopeRefs(json['products']),
  );

  static List<AdminCouponScopeRef> _scopeRefs(Object? value) {
    if (value is! List) return const <AdminCouponScopeRef>[];
    return value
        .whereType<Map>()
        .map(
          (row) => AdminCouponScopeRef.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }
}
