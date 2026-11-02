import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

/// A coupon backed by `marketing.coupons`.
///
/// The old model stored the discount as display text (`Get 50% OFF`) and the
/// checkout scraped the percentage out of it with a regex. This stores the
/// numeric rule and derives display text from it instead.
class CouponModel {
  const CouponModel({
    required this.id,
    required this.code,
    String? title,
    String? description,
    this.titleAr,
    this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    this.discountType = 'percentage',
    this.discountValue = 0,
    this.maxDiscount,
    this.minOrderAmount = 0,
    this.message,
    this.usedCount = 0,
    this.perUserLimit,
    this.usageLimit,
    this.totalUsed = 0,
    this.appliesTo = 'all',
    this.scopeCategoryIds = const [],
    this.scopeProductIds = const [],
    this.scopeNamesAr = const [],
    this.scopeNamesEn = const [],
  }) : _legacyTitle = title ?? '',
       _legacyDescription = description ?? '';

  final String id;
  final String code;
  final String? titleAr;
  final String? titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String discountType;
  final double discountValue;
  final double? maxDiscount;
  final double minOrderAmount;

  /// Server validation message (`applied`, `code expired`, ...). Null for
  /// unvalidated catalogue rows.
  final String? message;

  // --- Per-customer usage, from `public.coupon_availability()` -------------
  //
  // Without these the list could only show "here is a coupon" and a customer
  // who had spent their allowance found out at checkout, from an English error.

  /// Times this customer has already completed an order with this coupon.
  final int usedCount;

  /// Times this customer may use it. Null when the server did not report one.
  final int? perUserLimit;

  /// Total redemptions across all customers. Null means unlimited.
  final int? usageLimit;

  /// Redemptions across all customers, against [usageLimit].
  final int totalUsed;

  // --- Scope ---------------------------------------------------------------
  //
  // 'all' | 'category' | 'product'. Without this the app could not say *why* a
  // scoped coupon refused to apply: the server knew, the client had no idea.

  final String appliesTo;
  final List<String> scopeCategoryIds;
  final List<String> scopeProductIds;
  final List<String> scopeNamesAr;
  final List<String> scopeNamesEn;

  bool get isScoped => appliesTo == 'category' || appliesTo == 'product';

  /// The items this coupon is limited to, in the app's current language.
  ///
  /// Falls back to the other language rather than rendering an empty chip: a
  /// category may have a name in one language only.
  List<String> get scopeNames {
    bool filled(List<String> names) =>
        names.any((name) => name.trim().isNotEmpty);
    final ar = scopeNamesAr;
    final en = scopeNamesEn;
    if (AppLocale.instance.isArabic) {
      return filled(ar) ? ar : en;
    }
    return filled(en) ? en : ar;
  }

  /// A short label naming the scope, for "this coupon applies to X".
  ///
  /// Empty for an unscoped coupon, which the UI phrases as "applies to
  /// everything in your cart" instead.
  String get scopeLabel =>
      scopeNames.join(AppLocale.instance.isArabic ? '، ' : ', ');

  /// Whether this coupon only discounts part of the cart.
  ///
  /// The server prices a scoped coupon on the eligible lines alone, so a 20%
  /// coupon limited to cold drinks takes 20% off the cold drinks and nothing
  /// off the rest of the basket. That is correct and it surprises people, so the
  /// card says so instead of leaving them to work out why the discount is small.
  bool get discountsOnlyScope => isScoped;

  /// Uses this customer has left, or null when the answer is not known.
  ///
  /// Never negative: a customer who somehow exceeded the limit is shown zero,
  /// not a negative count that would render as a nonsense badge.
  int? get remainingUses {
    final limit = perUserLimit;
    if (limit == null) return null;
    return (limit - usedCount).clamp(0, limit);
  }

  /// Per-customer allowance only. The picker hides these coupons for this
  /// account; a global limit is shown as sold out instead of hiding the offer
  /// from every customer.
  bool get usedUpByCustomer => remainingUses != null && remainingUses! <= 0;

  /// True when this customer can no longer use it.
  ///
  /// A shared coupon that everyone else has burned through reads as "sold out"
  /// rather than "hidden", which is why both reasons are folded in here.
  bool get isExhaustedForMe {
    final remaining = remainingUses;
    if (remaining != null && remaining <= 0) return true;
    final global = usageLimit;
    return global != null && totalUsed >= global;
  }

  final String _legacyTitle;
  final String _legacyDescription;

  String get title {
    final text = pickText((
      ar: titleAr ?? '',
      en: titleEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return text.isEmpty ? _legacyTitle : text;
  }

  String get description {
    final text = pickText((
      ar: descriptionAr ?? '',
      en: descriptionEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return text.isEmpty ? _legacyDescription : text;
  }

  /// Human-readable rule derived from the numeric fields, in the app language.
  String get discount {
    if (discountType == 'percentage') {
      final percent = discountValue == discountValue.roundToDouble()
          ? discountValue.toInt().toString()
          : discountValue.toString();
      final capped = maxDiscount == null
          ? null
          : Formatters.price(maxDiscount!);
      return S.couponPercentOff(percent, capped);
    }
    return S.couponAmountOff(Formatters.price(discountValue));
  }

  /// The same coupon with its discount rule replaced.
  ///
  /// The rule is stored on the row and never recomputed, so this exists for
  /// tests and for a server answer that restates the offer.
  CouponModel copyWith({
    String? discountType,
    double? discountValue,
    double? maxDiscount,
    String? message,
  }) => CouponModel(
    id: id,
    code: code,
    title: _legacyTitle,
    description: _legacyDescription,
    titleAr: titleAr,
    titleEn: titleEn,
    descriptionAr: descriptionAr,
    descriptionEn: descriptionEn,
    discountType: discountType ?? this.discountType,
    discountValue: discountValue ?? this.discountValue,
    maxDiscount: maxDiscount ?? this.maxDiscount,
    minOrderAmount: minOrderAmount,
    message: message ?? this.message,
    usedCount: usedCount,
    perUserLimit: perUserLimit,
    usageLimit: usageLimit,
    totalUsed: totalUsed,
    appliesTo: appliesTo,
    scopeCategoryIds: scopeCategoryIds,
    scopeProductIds: scopeProductIds,
    scopeNamesAr: scopeNamesAr,
    scopeNamesEn: scopeNamesEn,
  );

  factory CouponModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return CouponModel(
      id: Db.text(map['id']),
      code: Db.text(map['code']),
      titleAr: Db.textOrNull(map['title_ar']),
      titleEn: Db.textOrNull(map['title_en']),
      descriptionAr: Db.textOrNull(map['description_ar']),
      descriptionEn: Db.textOrNull(map['description_en']),
      discountType: Db.text(map['discount_type'], 'percentage'),
      discountValue: Db.asDouble(map['discount_value']),
      maxDiscount: Db.asDoubleOrNull(map['max_discount']),
      minOrderAmount: Db.asDouble(map['min_order_amount']),
      usedCount: Db.asInt(map['used_count']),
      perUserLimit: Db.asIntOrNull(map['per_user_limit']),
      usageLimit: Db.asIntOrNull(map['usage_limit']),
      totalUsed: Db.asInt(map['total_used']),
      appliesTo: Db.text(map['applies_to'], 'all'),
    );
  }

  /// Carries the customer's usage and scope over from [other]; every field the
  /// card needs is preserved.
  CouponModel withUsage(CouponModel other) => CouponModel(
    id: id,
    code: code,
    titleAr: titleAr,
    titleEn: titleEn,
    descriptionAr: descriptionAr,
    descriptionEn: descriptionEn,
    discountType: discountType,
    discountValue: discountValue,
    maxDiscount: maxDiscount,
    minOrderAmount: minOrderAmount,
    message: message,
    usedCount: other.usedCount,
    perUserLimit: other.perUserLimit,
    usageLimit: other.usageLimit,
    totalUsed: other.totalUsed,
    appliesTo: other.appliesTo,
    scopeCategoryIds: other.scopeCategoryIds,
    scopeProductIds: other.scopeProductIds,
    scopeNamesAr: other.scopeNamesAr,
    scopeNamesEn: other.scopeNamesEn,
  );

  ValidatedCoupon validated({
    required double discount,
    required double subtotal,
    String? message,
  }) => ValidatedCoupon(
    coupon: copyWith(message: message),
    discount: discount,
    subtotal: subtotal,
  );
}

/// A coupon plus the exact discount the server approved for one subtotal.
///
/// The amount is never reused for a different subtotal: checkout revalidates
/// whenever the cart changes.
class ValidatedCoupon {
  const ValidatedCoupon({
    required this.coupon,
    required this.discount,
    required this.subtotal,
    this.lines = const [],
  });

  final CouponModel coupon;
  final double discount;
  final double subtotal;

  /// Which cart lines the discount came off.
  ///
  /// Empty when the server could not break it down (older deployment) — the
  /// total is still correct, only the explanation is missing, so callers must
  /// treat this as optional.
  final List<CouponLineDiscount> lines;

  /// The lines a scoped coupon actually covered.
  List<CouponLineDiscount> get discountedLines =>
      lines.where((line) => line.discount > 0).toList();

  /// True when some lines were left out, which is the case worth explaining.
  bool get isPartial =>
      lines.isNotEmpty && discountedLines.length < lines.length;

  /// The same approval carrying a breakdown fetched separately.
  ///
  /// The discount is never recomputed here: only the explanation is added.
  ValidatedCoupon copyWithLines(List<CouponLineDiscount> lines) =>
      ValidatedCoupon(
        coupon: coupon,
        discount: discount,
        subtotal: subtotal,
        lines: lines,
      );
}

/// One cart line's share of an approved coupon discount.
class CouponLineDiscount {
  const CouponLineDiscount({
    required this.productId,
    required this.lineTotal,
    required this.discount,
    this.nameAr = '',
    this.nameEn = '',
    this.isEligible = true,
  });

  final String productId;
  final double lineTotal;

  /// This line's share of the discount. Zero on lines a scoped coupon skipped.
  final double discount;

  final String nameAr;
  final String nameEn;

  /// Whether the coupon's scope covers this line at all.
  ///
  /// Kept separate from [discount] because a zero discount on an eligible line
  /// (a rounding share too small to be a cent) means something different from
  /// a zero discount on an out-of-scope line.
  final bool isEligible;

  /// What the line costs after the discount.
  double get payableTotal => lineTotal - discount;

  String get name =>
      pickText((ar: nameAr, en: nameEn), isArabic: AppLocale.instance.isArabic);

  factory CouponLineDiscount.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return CouponLineDiscount(
      productId: Db.text(map['product_id']),
      nameAr: Db.text(map['product_name_ar']),
      nameEn: Db.text(map['product_name_en']),
      lineTotal: Db.asDouble(map['line_total']),
      discount: Db.asDouble(map['discount']),
      isEligible: map['eligible'] == true,
    );
  }
}
