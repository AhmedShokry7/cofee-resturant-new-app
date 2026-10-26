import 'package:admin_app/features/coupons/domain/entities/admin_coupon_targets.dart';
import 'package:admin_app/features/coupons/domain/repositories/coupon_repository.dart';

/// قراءة كتالوج أهداف الكوبونات.
class LoadTargetsUseCase {
  const LoadTargetsUseCase(this._repository);

  final CouponRepository _repository;

  Future<AdminCouponTargets> call() => _repository.loadTargets();
}
