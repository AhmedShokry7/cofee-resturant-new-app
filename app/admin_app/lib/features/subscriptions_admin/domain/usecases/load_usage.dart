import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_usage.dart';
import 'package:admin_app/features/subscriptions_admin/domain/repositories/subscription_repository.dart';

/// قراءة سجل استخدام اشتراك واحد.
class LoadUsageUseCase {
  const LoadUsageUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<List<AdminSubscriptionUsage>> call(String subscriptionId) =>
      _repository.loadUsage(subscriptionId);
}
