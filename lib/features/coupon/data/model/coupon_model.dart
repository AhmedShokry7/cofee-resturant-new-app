import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
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
  })  : _legacyTitle = title ?? '',
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

  final String _legacyTitle;
  final String _legacyDescription;

  String get title {
    final text = pickText(
      (ar: titleAr ?? '', en: titleEn ?? ''),
      isArabic: AppLocale.instance.isArabic,
    );
    return text.isEmpty ? _legacyTitle : text;
  }

  String get description {
    final text = pickText(
      (ar: descriptionAr ?? '', en: descriptionEn ?? ''),
      isArabic: AppLocale.instance.isArabic,
    );
    return text.isEmpty ? _legacyDescription : text;
  }

  /// Human-readable rule derived from the numeric fields.
  String get discount {
    if (discountType == 'percentage') {
      final percent = discountValue == discountValue.roundToDouble()
          ? discountValue.toInt().toString()
          : discountValue.toString();
      final capped = maxDiscount == null
          ? ''
          : ' up to ${Formatters.price(maxDiscount!)}';
      return '$percent% off$capped';
    }
    return '${Formatters.price(discountValue)} off';
  }

  double discountFor(double subtotal) {
    if (subtotal < minOrderAmount) return 0;
    final amount = discountType == 'percentage'
        ? subtotal * discountValue / 100
        : discountValue;
    final capped = maxDiscount == null ? amount : amount.clamp(0, maxDiscount!);
    return capped.clamp(0, subtotal).toDouble();
  }

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
    );
  }

  ValidatedCoupon validated({
    required double discount,
    required double subtotal,
    String? message,
  }) =>
      ValidatedCoupon(
        coupon: CouponModel(
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
          message: message ?? this.message,
        ),
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
  });

  final CouponModel coupon;
  final double discount;
  final double subtotal;
}

