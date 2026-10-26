import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

/// What a loyalty reward hands over when it is redeemed.
enum RewardTargetType {
  product,
  bundle,
  plan;

  String get wireValue => switch (this) {
    RewardTargetType.product => 'product',
    RewardTargetType.bundle => 'bundle',
    RewardTargetType.plan => 'plan',
  };

  bool get isProduct => this == RewardTargetType.product;

  /// Product and bundle rewards are handed over at a branch; a subscription
  /// plan is account-wide and can be redeemed without choosing one.
  bool get needsBranch => this != RewardTargetType.plan;

  static RewardTargetType fromWire(Object? value) => switch ('$value') {
    'bundle' => RewardTargetType.bundle,
    'plan' => RewardTargetType.plan,
    _ => RewardTargetType.product,
  };
}

/// A redeemable loyalty reward backed by `public.loyalty_rewards`.
///
/// The same catalogue lists product, bundle and subscription-plan rewards.
/// [product] is only populated for product rewards because the guest device
/// cart needs the full product; a signed-in redemption is executed on the
/// server from [id] and becomes a free pickup order (or a subscription).
class RewardModel {
  const RewardModel({
    required this.type,
    required this.targetId,
    required this.pointsCost,
    this.id,
    this.product,
    this.nameAr,
    this.nameEn,
    this.imageUrl,
    this.stockAvailable,
    this.isActive = true,
  });

  final RewardTargetType type;

  /// Id of the product, bundle or plan this reward grants.
  final String targetId;

  final ProductModel? product;

  final String? nameAr;
  final String? nameEn;
  final String? imageUrl;

  final int pointsCost;

  /// Database reward id. Null only for legacy local models.
  final String? id;

  /// Remaining redemptions, when tracked. Null means unlimited.
  final int? stockAvailable;

  final bool isActive;

  bool get isOutOfStock => stockAvailable != null && stockAvailable! <= 0;

  bool get isProduct => type.isProduct;

  bool affordable(int balance) => !isOutOfStock && balance >= pointsCost;

  /// Name from the reward view, falling back to the joined product.
  String get name => pickText(
    (ar: nameAr ?? '', en: nameEn ?? ''),
    isArabic: AppLocale.instance.isArabic,
    fallback: product?.name ?? '',
  );

  /// Picture from the reward view, falling back to the joined product.
  String? get image {
    final url = imageUrl?.trim() ?? '';
    if (url.isNotEmpty) return url;
    return product?.displayImageUrl;
  }

  factory RewardModel.fromDatabase({
    required Map<String, dynamic> row,
    ProductModel? product,
  }) {
    final map = Db.asMap(row);
    final type = RewardTargetType.fromWire(map['reward_type']);
    return RewardModel(
      type: type,
      targetId: switch (type) {
        RewardTargetType.product => Db.text(map['product_id']),
        RewardTargetType.bundle => Db.text(map['bundle_id']),
        RewardTargetType.plan => Db.text(map['plan_id']),
      },
      product: product,
      pointsCost: Db.asInt(map['points_cost']),
      id: Db.textOrNull(map['id']),
      nameAr: Db.textOrNull(map['name_ar']),
      nameEn: Db.textOrNull(map['name_en']),
      imageUrl: Db.textOrNull(map['image_url']),
      stockAvailable: map['stock_available'] == null
          ? null
          : Db.asInt(map['stock_available']),
      isActive: Db.asBool(map['is_active'], fallback: true),
    );
  }
}

/// One earn rate from `loyalty.loyalty_rules`.
class LoyaltyRule {
  const LoyaltyRule({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.pointsPerCurrencyUnit,
    this.isActive = true,
  });

  final String code;
  final String nameAr;
  final String nameEn;
  final double pointsPerCurrencyUnit;
  final bool isActive;

  String get name =>
      pickText((ar: nameAr, en: nameEn), isArabic: AppLocale.instance.isArabic);

  int pointsFor(double amount) =>
      (amount * pointsPerCurrencyUnit).floor().clamp(0, 1 << 31);

  factory LoyaltyRule.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return LoyaltyRule(
      code: Db.text(map['code']),
      nameAr: Db.text(map['name_ar']),
      nameEn: Db.text(map['name_en']),
      pointsPerCurrencyUnit: Db.asDouble(map['points_per_currency_unit']),
      isActive: Db.asBool(map['is_active'], fallback: true),
    );
  }
}
