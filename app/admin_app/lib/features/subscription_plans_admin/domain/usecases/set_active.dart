import 'package:admin_app/features/subscription_plans_admin/domain/repositories/subscription_plan_repository.dart';

/// تفعيل خطة الاشتراك أو تعطيلها.
class SetActiveUseCase {
  const SetActiveUseCase(this._repository);

  final SubscriptionPlanRepository _repository;

  Future<bool> call(String planId, bool active) =>
      _repository.setActive(planId, active);
}
