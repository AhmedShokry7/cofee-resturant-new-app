import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward_type.dart';
import 'package:admin_app/features/loyalty/data/models/loyalty_json.dart';

/// A catalogue entry a reward can unlock: a product, a bundle or a plan.
class AdminLoyaltyTargetOption {
  const AdminLoyaltyTargetOption({
    required this.type,
    required this.id,
    this.nameAr,
    this.nameEn,
    this.code,
    this.imageUrl,
    this.price = 0,
    this.isActive = true,
    this.categoryNameAr,
    this.categoryNameEn,
    this.bundleItemsCount,
    this.planDurationDays,
    this.planCupsPerCycle,
    this.rewardId,
    this.rewardPointsCost,
    this.rewardIsActive = false,
  });

  final AdminLoyaltyRewardType type;
  final String id;
  final String? nameAr;
  final String? nameEn;
  final String? code;
  final String? imageUrl;
  final double price;
  final bool isActive;
  final String? categoryNameAr;
  final String? categoryNameEn;
  final int? bundleItemsCount;
  final int? planDurationDays;
  final int? planCupsPerCycle;

  /// Set when the target already belongs to another reward.
  final String? rewardId;
  final int? rewardPointsCost;
  final bool rewardIsActive;

  bool get hasReward => rewardId != null;

  bool isSameTarget(AdminLoyaltyRewardType type, String id) =>
      this.type == type && this.id == id;

  String nameFor(AppLanguage language) {
    final name = language.isArabic ? nameAr?.trim() : nameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic ? nameEn?.trim() : nameAr?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return code?.trim() ?? '';
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

  factory AdminLoyaltyTargetOption.fromJson(Map<String, dynamic> json) {
    return AdminLoyaltyTargetOption(
      type: AdminLoyaltyRewardType.fromWire(json['type']),
      id: '${json['id'] ?? ''}',
      nameAr: json['name_ar'] as String?,
      nameEn: json['name_en'] as String?,
      code: json['code'] as String?,
      imageUrl: json['image_url'] as String?,
      price: loyaltyDouble(json['price']),
      isActive: json['is_active'] == true,
      categoryNameAr: json['category_name_ar'] as String?,
      categoryNameEn: json['category_name_en'] as String?,
      bundleItemsCount: (json['bundle_items_count'] as num?)?.toInt(),
      planDurationDays: (json['plan_duration_days'] as num?)?.toInt(),
      planCupsPerCycle: (json['plan_cups_per_cycle'] as num?)?.toInt(),
      rewardId: json['reward_id'] as String?,
      rewardPointsCost: (json['reward_points_cost'] as num?)?.toInt(),
      rewardIsActive: json['reward_is_active'] == true,
    );
  }
}
