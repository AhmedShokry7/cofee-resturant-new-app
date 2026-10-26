import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward_type.dart';
import 'package:admin_app/features/loyalty/data/models/loyalty_json.dart';

enum AdminLoyaltyRewardState { active, paused, outOfStock, unavailable }

class AdminLoyaltyReward {
  const AdminLoyaltyReward({
    required this.id,
    required this.type,
    required this.targetId,
    required this.pointsCost,
    this.stockAvailable,
    this.isActive = true,
    this.targetNameAr,
    this.targetNameEn,
    this.targetCode,
    this.targetImageUrl,
    this.targetPrice = 0,
    this.targetIsActive = true,
    this.targetIsAvailable = true,
    this.categoryNameAr,
    this.categoryNameEn,
    this.bundleItemsCount = 0,
    this.planDurationDays,
    this.planCupsPerCycle,
    this.redemptionsCount = 0,
    this.lastRedeemedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final AdminLoyaltyRewardType type;
  final String targetId;
  final int pointsCost;

  /// null means an unlimited number of redemptions.
  final int? stockAvailable;
  final bool isActive;
  final String? targetNameAr;
  final String? targetNameEn;
  final String? targetCode;
  final String? targetImageUrl;
  final double targetPrice;
  final bool targetIsActive;
  final bool targetIsAvailable;
  final String? categoryNameAr;
  final String? categoryNameEn;
  final int bundleItemsCount;
  final int? planDurationDays;
  final int? planCupsPerCycle;
  final int redemptionsCount;
  final DateTime? lastRedeemedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasUnlimitedStock => stockAvailable == null;
  bool get isOutOfStock => stockAvailable != null && stockAvailable! <= 0;
  bool get wasRedeemed => redemptionsCount > 0;

  AdminLoyaltyRewardState get state {
    if (!isActive) return AdminLoyaltyRewardState.paused;
    if (!targetIsAvailable) return AdminLoyaltyRewardState.unavailable;
    if (isOutOfStock) return AdminLoyaltyRewardState.outOfStock;
    return AdminLoyaltyRewardState.active;
  }

  String targetNameFor(AppLanguage language) {
    final name = language.isArabic
        ? targetNameAr?.trim()
        : targetNameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic
        ? targetNameEn?.trim()
        : targetNameAr?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return targetCode?.trim() ?? '';
  }

  String? categoryNameFor(AppLanguage language) {
    final name = language.isArabic
        ? categoryNameAr?.trim()
        : categoryNameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic
        ? categoryNameEn?.trim()
        : categoryNameAr?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  factory AdminLoyaltyReward.fromJson(Map<String, dynamic> json) {
    return AdminLoyaltyReward(
      id: '${json['id'] ?? ''}',
      type: AdminLoyaltyRewardType.fromWire(json['reward_type']),
      targetId:
          '${json['target_id'] ?? json['product_id'] ?? json['bundle_id'] ?? json['plan_id'] ?? ''}',
      pointsCost: loyaltyInt(json['points_cost']),
      stockAvailable: (json['stock_available'] as num?)?.toInt(),
      isActive: json['is_active'] == true,
      targetNameAr: json['target_name_ar'] as String?,
      targetNameEn: json['target_name_en'] as String?,
      targetCode: json['target_code'] as String?,
      targetImageUrl: json['target_image_url'] as String?,
      targetPrice: loyaltyDouble(json['target_price']),
      targetIsActive: json['target_is_active'] == true,
      targetIsAvailable: json['target_is_available'] == true,
      categoryNameAr: json['category_name_ar'] as String?,
      categoryNameEn: json['category_name_en'] as String?,
      bundleItemsCount: loyaltyInt(json['bundle_items_count']),
      planDurationDays: (json['plan_duration_days'] as num?)?.toInt(),
      planCupsPerCycle: (json['plan_cups_per_cycle'] as num?)?.toInt(),
      redemptionsCount: loyaltyInt(json['redemptions_count']),
      lastRedeemedAt: loyaltyDate(json['last_redeemed_at']),
      createdAt: loyaltyDate(json['created_at']),
      updatedAt: loyaltyDate(json['updated_at']),
    );
  }
}
