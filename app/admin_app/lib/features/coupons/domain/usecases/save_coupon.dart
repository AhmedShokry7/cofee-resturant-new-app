import 'package:admin_app/features/coupons/domain/entities/admin_coupon_draft.dart';
import 'package:admin_app/features/coupons/domain/repositories/coupon_repository.dart';

/// حفظ كوبون (مسودة جديدة أو تعديل قائم).
class SaveCouponUseCase {
  const SaveCouponUseCase(this._repository);

  final CouponRepository _repository;

  Future<CouponSaveOutcome> call(AdminCouponDraft draft) =>
      _repository.saveCoupon(draft);
}
