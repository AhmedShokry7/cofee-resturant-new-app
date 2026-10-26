import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_usage.dart';

/// نتيجة إلغاء اشتراك كما تعيدها القاعدة.
enum SubscriptionCancelOutcome {
  cancelled,
  notFound,
  notCancellable,
  reservedCups,
  failed,
}

/// عقد قراءة الاشتراكات واستخداماتها وكتابة إلغاء الاشتراك.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class SubscriptionRepository {
  /// يقرأ كل الاشتراكات بترتيب القاعدة.
  Future<List<AdminSubscription>> loadSubscriptions();

  /// يقرأ سجل استخدام اشتراك واحد بترتيب القاعدة.
  Future<List<AdminSubscriptionUsage>> loadUsage(String subscriptionId);

  /// يلغي الاشتراك ويعيد نتيجة العملية كما تعيدها القاعدة.
  Future<SubscriptionCancelOutcome> cancelSubscription(String subscriptionId);
}
