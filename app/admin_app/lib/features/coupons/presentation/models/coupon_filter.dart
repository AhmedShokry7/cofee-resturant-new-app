import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_format.dart';

enum AdminCouponFilter {
  all,
  active,
  expiringSoon,
  scheduled,
  exhausted,
  expired,
  paused,
}

extension AdminCouponFilterView on AdminCouponFilter {
  String get label => switch (this) {
    AdminCouponFilter.all => S.couponsFilterAll,
    AdminCouponFilter.active => S.couponsStatusActive,
    AdminCouponFilter.expiringSoon => S.couponsStatusExpiringSoon,
    AdminCouponFilter.scheduled => S.couponsStatusScheduled,
    AdminCouponFilter.exhausted => S.couponsStatusExhausted,
    AdminCouponFilter.expired => S.couponsStatusExpired,
    AdminCouponFilter.paused => S.couponsStatusPaused,
  };

  AdminCouponStatus? get _status => switch (this) {
    AdminCouponFilter.all => null,
    AdminCouponFilter.active => AdminCouponStatus.active,
    AdminCouponFilter.expiringSoon => AdminCouponStatus.expiringSoon,
    AdminCouponFilter.scheduled => AdminCouponStatus.scheduled,
    AdminCouponFilter.exhausted => AdminCouponStatus.exhausted,
    AdminCouponFilter.expired => AdminCouponStatus.expired,
    AdminCouponFilter.paused => AdminCouponStatus.paused,
  };

  bool matches(AdminCoupon coupon) {
    final status = _status;
    return status == null || coupon.statusAt() == status;
  }
}

List<AdminCoupon> filterCoupons(
  List<AdminCoupon> coupons, {
  String search = '',
  AdminCouponFilter filter = AdminCouponFilter.all,
}) {
  final query = search.trim().toLowerCase();
  final language = AppLocale.instance.language;
  return coupons
      .where((coupon) {
        if (!filter.matches(coupon)) return false;
        if (query.isEmpty) return true;
        final text = <String>[
          coupon.code,
          coupon.titleAr,
          coupon.titleEn,
          coupon.descriptionAr ?? '',
          coupon.descriptionEn ?? '',
          couponStatusLabel(coupon),
          for (final category in coupon.categories) ...[
            category.nameAr ?? '',
            category.nameEn ?? '',
          ],
          for (final product in coupon.products) ...[
            product.nameAr ?? '',
            product.nameEn ?? '',
          ],
          coupon.titleFor(language),
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}
