import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.price,
    this.currencyCode = 'SAR',
    this.durationDays = 30,
    this.cupsPerCycle = 0,
    this.bonusType = 'none',
    this.bonusValue = 0,
    this.bonusExpiresWithCycle = true,
    this.rolloverCapCups = 0,
    this.renewalPolicy = 'manual',
    this.autoRenewSupported = false,
    this.allBranches = true,
    this.productScope = 'all',
    this.isActive = true,
    this.isForSale = true,
    this.imageUrl,
    this.branchIds = const [],
    this.productIds = const [],
  });

  final String id;
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
  final bool allBranches;
  final String productScope;
  final bool isActive;
  final bool isForSale;
  final String? imageUrl;
  final List<String> branchIds;
  final List<String> productIds;

  /// The name in the language the customer reads the app in, falling back to
  /// the other language when the CMS left that half of the row empty.
  String get name =>
      pickText((ar: nameAr, en: nameEn), isArabic: AppLocale.instance.isArabic);

  String get description => pickText((
    ar: descriptionAr ?? '',
    en: descriptionEn ?? '',
  ), isArabic: AppLocale.instance.isArabic);

  factory SubscriptionPlan.fromDatabase(Map<String, dynamic> row) {
    final map = Db.asMap(row);
    return SubscriptionPlan(
      id: Db.text(map['id']),
      code: Db.text(map['code']),
      nameAr: Db.text(map['name_ar']),
      nameEn: Db.text(map['name_en']),
      descriptionAr: Db.textOrNull(map['description_ar']),
      descriptionEn: Db.textOrNull(map['description_en']),
      price: Db.asDouble(map['price']),
      currencyCode: Db.text(map['currency_code'], 'SAR'),
      durationDays: Db.asInt(map['duration_days'], fallback: 30),
      cupsPerCycle: Db.asInt(map['cups_per_cycle']),
      bonusType: Db.text(map['bonus_type'], 'none'),
      bonusValue: Db.asDouble(map['bonus_value']),
      bonusExpiresWithCycle: Db.asBool(
        map['bonus_expires_with_cycle'],
        fallback: true,
      ),
      rolloverCapCups: Db.asInt(map['rollover_cap_cups']),
      renewalPolicy: Db.text(map['renewal_policy'], 'manual'),
      autoRenewSupported: Db.asBool(map['auto_renew_supported']),
      allBranches: Db.asBool(map['all_branches'], fallback: true),
      productScope: Db.text(map['product_scope'], 'all'),
      isActive: Db.asBool(map['is_active'], fallback: true),
      isForSale: Db.asBool(map['is_for_sale'], fallback: true),
      imageUrl: Db.textOrNull(map['image_url']),
      branchIds: _stringList(map['branch_ids']),
      productIds: _stringList(map['product_ids']),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return [for (final item in value) item.toString()];
    }
    return const [];
  }
}
