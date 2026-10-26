import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';

class AdminCouponDraft {
  const AdminCouponDraft({
    this.id,
    required this.code,
    required this.titleAr,
    required this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.discountType,
    required this.discountValue,
    this.maxDiscount,
    this.minOrderAmount = 0,
    required this.scope,
    this.categoryIds = const <String>[],
    this.productIds = const <String>[],
    this.usageLimit,
    this.perUserLimit = 1,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
  });

  final String? id;
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
  final List<String> categoryIds;
  final List<String> productIds;
  final int? usageLimit;
  final int perUserLimit;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'code': code,
    'title_ar': titleAr,
    'title_en': titleEn,
    'description_ar': descriptionAr,
    'description_en': descriptionEn,
    'discount_type': discountType.wireValue,
    'discount_value': discountValue,
    'max_discount': discountType == AdminCouponDiscountType.percentage
        ? maxDiscount
        : null,
    'min_order_amount': minOrderAmount,
    'applies_to': scope.wireValue,
    'category_ids': scope == AdminCouponScope.category
        ? categoryIds
        : const <String>[],
    'product_ids': scope == AdminCouponScope.product
        ? productIds
        : const <String>[],
    'usage_limit': usageLimit,
    'per_user_limit': perUserLimit,
    'starts_at': startsAt?.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'is_active': isActive,
  };
}
