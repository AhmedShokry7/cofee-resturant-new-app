import 'package:admin_app/features/subscriptions_admin/domain/repositories/subscription_repository.dart';

/// إلغاء اشتراك قائم.
class CancelSubscriptionUseCase {
  const CancelSubscriptionUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<SubscriptionCancelOutcome> call(String subscriptionId) =>
      _repository.cancelSubscription(subscriptionId);
}
