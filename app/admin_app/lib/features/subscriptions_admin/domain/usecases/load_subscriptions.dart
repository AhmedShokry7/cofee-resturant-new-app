import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/domain/repositories/subscription_repository.dart';

/// قراءة كل اشتراكات اللوحة.
class LoadSubscriptionsUseCase {
  const LoadSubscriptionsUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<List<AdminSubscription>> call() => _repository.loadSubscriptions();
}
