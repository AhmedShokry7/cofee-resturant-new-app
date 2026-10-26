import 'package:admin_app/features/subscription_plans_admin/data/repositories/admin_subscription_plan_repository.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/repositories/subscription_plan_repository.dart';

/// نقطة تركيب اعتمادات فيتشر باقات الاشتراك داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class SubscriptionPlansAdminDependencies {
  SubscriptionPlansAdminDependencies._();

  static SubscriptionPlanRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static SubscriptionPlanRepository get repository =>
      _repository ??= AdminSubscriptionPlanRepository();
}
