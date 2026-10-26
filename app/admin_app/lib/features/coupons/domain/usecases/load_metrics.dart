import 'package:admin_app/features/coupons/domain/entities/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/domain/repositories/coupon_repository.dart';

/// قراءة ملخص مؤشرات الكوبونات.
class LoadMetricsUseCase {
  const LoadMetricsUseCase(this._repository);

  final CouponRepository _repository;

  Future<AdminCouponMetrics> call() => _repository.loadMetrics();
}
