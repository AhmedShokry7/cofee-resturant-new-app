import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/repositories/subscription_plan_repository.dart';

/// قراءة كل باقات الاشتراك.
class LoadPlansUseCase {
  const LoadPlansUseCase(this._repository);

  final SubscriptionPlanRepository _repository;

  Future<List<AdminSubscriptionPlan>> call() => _repository.loadPlans();
}
