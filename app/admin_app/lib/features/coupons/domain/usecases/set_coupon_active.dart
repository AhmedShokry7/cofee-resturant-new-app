import 'package:admin_app/features/coupons/domain/repositories/coupon_repository.dart';

/// تنشيط الكوبون أو إيقافه بعد فحص القاعدة.
class SetCouponActiveUseCase {
  const SetCouponActiveUseCase(this._repository);

  final CouponRepository _repository;

  Future<CouponMutationOutcome> call(String couponId, bool active) =>
      _repository.setCouponActive(couponId, active);
}
