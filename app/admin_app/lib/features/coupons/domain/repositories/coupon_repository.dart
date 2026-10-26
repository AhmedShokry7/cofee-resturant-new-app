import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_draft.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_targets.dart';

/// نتيجة حفظ كوبون (إنشاء أو تعديل) كما تعيدها القاعدة.
enum CouponSaveOutcome {
  saved,
  duplicateCode,
  invalidCode,
  invalidTitle,
  invalidDiscount,
  invalidLimit,
  invalidWindow,
  invalidScope,
  notFound,
  failed,
}

/// نتيجة تعديل كوبون (تنشيط أو حذف) كما تعيدها القاعدة.
enum CouponMutationOutcome { success, notFound, hasRedemptions, failed }

/// عقد قراءة الكوبونات ومؤشراتها وأهدافها وكتابة حالاتها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class CouponRepository {
  /// يقرأ كل الكوبونات بترتيب القاعدة.
  Future<List<AdminCoupon>> loadCoupons();

  /// يقرأ ملخص مؤشرات الكوبونات.
  Future<AdminCouponMetrics> loadMetrics();

  /// يقرأ كتالوج أهداف الكوبونات القابلة للاختيار.
  Future<AdminCouponTargets> loadTargets();

  /// يحفظ الكوبون ويعيد نتيجة العملية.
  Future<CouponSaveOutcome> saveCoupon(AdminCouponDraft draft);

  /// ينشط الكوبون أو يوقفه ويعيد نتيجة العملية.
  Future<CouponMutationOutcome> setCouponActive(String couponId, bool active);

  /// يحذف الكوبون ويعيد نتيجة العملية.
  Future<CouponMutationOutcome> deleteCoupon(String couponId);
}
