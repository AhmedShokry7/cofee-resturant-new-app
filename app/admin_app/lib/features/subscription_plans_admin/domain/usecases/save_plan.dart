import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/repositories/subscription_plan_repository.dart';

/// حفظ خطة اشتراك.
class SavePlanUseCase {
  const SavePlanUseCase(this._repository);

  final SubscriptionPlanRepository _repository;

  Future<SubscriptionPlanSaveOutcome> call(AdminSubscriptionPlanDraft draft) =>
      _repository.savePlan(draft);
}
