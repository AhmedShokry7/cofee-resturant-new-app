import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

/// A redeemable loyalty reward backed by `loyalty.loyalty_rewards`.
class RewardModel {
  const RewardModel({
    required this.product,
    required this.pointsCost,
    this.id,
    this.stockAvailable,
    this.isActive = true,
  });

  final ProductModel product;
  final int pointsCost;

  /// Database reward id. Null only for legacy local models.
  final String? id;

  /// Remaining redemptions, when tracked. Null means unlimited.
  final int? stockAvailable;

  final bool isActive;

  bool get isOutOfStock => stockAvailable != null && stockAvailable! <= 0;

  bool affordable(int balance) => !isOutOfStock && balance >= pointsCost;

  factory RewardModel.fromDatabase({
    required Map<String, dynamic> row,
    required ProductModel product,
  }) {
    final map = Db.asMap(row);
    return RewardModel(
      product: product,
      pointsCost: Db.asInt(map['points_cost']),
      id: Db.textOrNull(map['id']),
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
