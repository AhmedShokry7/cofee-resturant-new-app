import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/domain/repositories/coupon_repository.dart';

/// قراءة كل كوبونات اللوحة.
class LoadCouponsUseCase {
  const LoadCouponsUseCase(this._repository);

  final CouponRepository _repository;

  Future<List<AdminCoupon>> call() => _repository.loadCoupons();
}
