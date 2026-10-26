import 'package:admin_app/features/coupons/data/repositories/admin_coupon_repository.dart';
import 'package:admin_app/features/coupons/domain/repositories/coupon_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الكوبونات داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class CouponsDependencies {
  CouponsDependencies._();

  static CouponRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static CouponRepository get repository =>
      _repository ??= AdminCouponRepository();
}
