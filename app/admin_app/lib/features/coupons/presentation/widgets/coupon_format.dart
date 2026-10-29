import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';

String couponCount(int value) => localizeDigits(formatCount(value));

String couponMoney(double value) => localizeDigits(formatAmount(value));

String couponCompactNumber(num value) {
  final rounded = value.roundToDouble();
  final text = (value - rounded).abs() < 0.0001
      ? rounded.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return localizeDigits(
    text.endsWith('.') ? text.substring(0, text.length - 1) : text,
  );
}

/// A coupon condition written as its label plus the money amount the UI marks
/// with the riyal symbol.
class CouponMoneyTerm {
  const CouponMoneyTerm(this.label, this.amount);

  final String label;
  final double amount;
}

String couponStatusLabel(AdminCoupon coupon) =>
    couponStatusName(coupon.statusAt());

String couponStatusName(AdminCouponStatus status) => switch (status) {
  AdminCouponStatus.active => S.couponsStatusActive,
  AdminCouponStatus.expiringSoon => S.couponsStatusExpiringSoon,
  AdminCouponStatus.scheduled => S.couponsStatusScheduled,
  AdminCouponStatus.exhausted => S.couponsStatusExhausted,
  AdminCouponStatus.expired => S.couponsStatusExpired,
  AdminCouponStatus.paused => S.couponsStatusPaused,
};

/// The discount headline. A percentage coupon keeps its prose; a fixed coupon
/// is the bare amount the UI wears the riyal mark on.
String couponDiscountHeadline(AdminCoupon coupon) => coupon.isPercentage
    ? localizeDigits(
        S.couponsPercentOff(couponCompactNumber(coupon.discountValue)),
      )
    : couponMoney(coupon.discountValue);

/// Whether `couponDiscountHeadline` is a money amount.
bool couponDiscountHeadlineIsMoney(AdminCoupon coupon) => !coupon.isPercentage;

/// The conditions under the headline, each amount marked by the UI.
List<CouponMoneyTerm> couponDiscountTerms(AdminCoupon coupon) => [
  if (coupon.minOrderAmount > 0)
    CouponMoneyTerm(S.couponsMinOrder('').trim(), coupon.minOrderAmount),
  if (coupon.hasMaxDiscount)
    CouponMoneyTerm(S.couponsMaxDiscount('').trim(), coupon.maxDiscount!),
];

String couponScopeLabel(AdminCoupon coupon) => switch (coupon.scope) {
  AdminCouponScope.all => S.couponsScopeAll,
  AdminCouponScope.category => S.couponsScopeCategories(
    coupon.categories.length,
  ),
  AdminCouponScope.product => S.couponsScopeProducts(coupon.products.length),
};

String couponScopeHint(AdminCoupon coupon) {
  if (coupon.scope == AdminCouponScope.all) return S.couponsScopeAllHint;
  final refs = coupon.scope == AdminCouponScope.category
      ? coupon.categories
      : coupon.products;
  if (refs.isEmpty) return S.couponsNoSelection;
  final language = AppLocale.instance.language;
  final names = refs.take(2).map((ref) => ref.nameFor(language)).join('  •  ');
  if (refs.length <= 2) return names;
  return '$names  +${couponCount(refs.length - 2)}';
}

String couponUsageLabel(AdminCoupon coupon) {
  final limit = coupon.usageLimit;
  if (limit == null) {
    return localizeDigits(S.couponsUsageUsed(coupon.redemptionsCount));
  }
  return localizeDigits(S.couponsUsageOf(coupon.redemptionsCount, limit));
}

String couponUsageDetail(AdminCoupon coupon) {
  final limit = coupon.usageLimit;
  if (limit == null) return S.couponsPerCustomer(coupon.perUserLimit);
  final remaining = coupon.remainingUses ?? 0;
  return '${S.couponsRemaining(remaining)}  •  ${S.couponsPerCustomer(coupon.perUserLimit)}';
}

String couponPerCustomerLabel(AdminCoupon coupon) =>
    S.couponsPerCustomer(coupon.perUserLimit);

String couponWindowLabel(AdminCoupon coupon) {
  final start = coupon.startsAt;
  final end = coupon.endsAt;
  if (start != null && end != null) {
    return S.couponsWindowRange(localizedDate(start), localizedDate(end));
  }
  if (start != null) return S.couponsStartsOn(localizedDate(start));
  if (end != null) return S.couponsEndsOn(localizedDate(end));
  return S.couponsNoEndDate;
}

String couponWindowDetail(AdminCoupon coupon) {
  final status = coupon.statusAt();
  final end = coupon.endsAt;
  if (status == AdminCouponStatus.expired && end != null) {
    return S.couponsExpiredOn(localizedDate(end));
  }
  final start = coupon.startsAt;
  if (status == AdminCouponStatus.scheduled && start != null) {
    return S.couponsScheduledFor(localizedDate(start));
  }
  final countdown = couponExpiryCountdown(coupon);
  if (countdown != null) return countdown;
  if (end == null) return S.couponsNoEndDate;
  return S.couponsEndsOn(localizedDate(end));
}

String? couponExpiryCountdown(AdminCoupon coupon) {
  final end = coupon.endsAt?.toLocal();
  if (end == null) return null;
  final now = DateTime.now();
  if (!end.isAfter(now)) return null;
  final today = DateTime(now.year, now.month, now.day);
  final endDay = DateTime(end.year, end.month, end.day);
  final days = endDay.difference(today).inDays;
  if (days <= 0) return S.couponsExpiresToday;
  if (days == 1) return S.couponsExpiresTomorrow;
  return S.couponsExpiresInDays(days);
}

/// The discount given away, as the amount the UI marks with the riyal symbol.
String couponPerformanceLabel(AdminCoupon coupon) =>
    couponMoney(coupon.discountGiven);

String couponPerformanceDetail(AdminCoupon coupon) {
  if (!coupon.wasRedeemed) return S.couponsNeverRedeemed;
  return S.couponsLastUsed(localizedDate(coupon.lastRedeemedAt));
}

String couponRowsLabel(int from, int to, int count) =>
    S.couponsRowsLabel(from, to, count);
