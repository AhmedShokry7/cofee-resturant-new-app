import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_usage.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_options.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';

/// نتيجة إلغاء اشتراك كما تعيدها القاعدة.
enum SubscriptionCancelOutcome {
  cancelled,
  notFound,
  notCancellable,
  reservedCups,
  failed,
}

enum SubscriptionRemoveOutcome { removed, notFound, reservedCups, failed }

/// عقد قراءة الاشتراكات واستخداماتها وكتابة إلغاء الاشتراك.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class SubscriptionRepository {
  /// يقرأ كل الاشتراكات بترتيب القاعدة.
  Future<List<AdminSubscription>> loadSubscriptions();

  Future<List<AdminSubscriptionCustomer>> searchCustomers(String query);

  Future<List<AdminSubscriptionPaymentMethod>> loadPaymentMethods();

  Future<List<AdminSubscriptionPlan>> loadAvailablePlans();

  Future<AdminCreateSubscriptionOutcome> createSubscription({
    required String customerId,
    required String planId,
    required String? paymentMethodId,
    required bool paymentConfirmed,
    required String idempotencyKey,
  });

  /// يقرأ سجل استخدام اشتراك واحد بترتيب القاعدة.
  Future<List<AdminSubscriptionUsage>> loadUsage(String subscriptionId);

  /// يلغي الاشتراك ويعيد نتيجة العملية كما تعيدها القاعدة.
  Future<SubscriptionCancelOutcome> cancelSubscription(String subscriptionId);

  /// Hides an admin-managed subscription while retaining its audit and usage history.
  Future<SubscriptionRemoveOutcome> removeSubscription(String subscriptionId);
}
