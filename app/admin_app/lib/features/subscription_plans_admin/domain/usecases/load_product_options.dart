import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_product.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/repositories/subscription_plan_repository.dart';

/// قراءة منتجات الكتالوج القابلة للربط الباقات.
class LoadProductOptionsUseCase {
  const LoadProductOptionsUseCase(this._repository);

  final SubscriptionPlanRepository _repository;

  Future<List<AdminSubscriptionPlanProduct>> call() =>
      _repository.loadProductOptions();
}
