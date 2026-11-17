import 'dart:typed_data';

import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_product.dart';

/// نتيجة حفظ خطة اشتراك كما تعيدها القاعدة.
enum SubscriptionPlanSaveOutcome {
  saved,
  duplicateCode,
  invalidData,
  missingProducts,
  invalidProducts,
  notFound,
  failed,
}

/// عقد قراءة باقات الاشتراك ومنتجاتها وكتابة حفظها وتفعيلها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class SubscriptionPlanRepository {
  /// يقرأ كل باقات الاشتراك بترتيب القاعدة.
  Future<List<AdminSubscriptionPlan>> loadPlans();

  /// يقرأ منتجات الكتالوج القابلة للربط الباقات.
  Future<List<AdminSubscriptionPlanProduct>> loadProductOptions();

  /// يحفظ خطة اشتراك ويعيد نتيجة العملية كما تعيدها القاعدة.
  Future<SubscriptionPlanSaveOutcome> savePlan(
    AdminSubscriptionPlanDraft draft,
  );

  /// يفعّل الخطة أو يعطّلها ويعيد هل تغيّرت الحالة.
  Future<bool> setActive(String planId, bool active);

  /// Changes the image URL used by customer-facing plan cards.
  Future<void> updatePlanImage(String planId, String? imageUrl);

  /// Uploads a plan image to the dedicated subscription-plan storage path.
  Future<String> uploadPlanImage({
    required String planId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  });

  /// Deletes a plan image file after its row no longer points to it.
  Future<void> deletePlanImageFile(String? imageUrl);
}
