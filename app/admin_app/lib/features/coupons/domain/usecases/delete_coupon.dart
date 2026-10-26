import 'package:admin_app/features/coupons/domain/repositories/coupon_repository.dart';

/// حذف كوبون بعد فحص القاعدة.
class DeleteCouponUseCase {
  const DeleteCouponUseCase(this._repository);

  final CouponRepository _repository;

  Future<CouponMutationOutcome> call(String couponId) =>
      _repository.deleteCoupon(couponId);
}
