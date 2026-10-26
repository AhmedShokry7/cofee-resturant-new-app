import 'package:admin_app/features/subscriptions_admin/data/repositories/admin_subscription_repository.dart';
import 'package:admin_app/features/subscriptions_admin/domain/repositories/subscription_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الاشتراكات داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class SubscriptionsAdminDependencies {
  SubscriptionsAdminDependencies._();

  static SubscriptionRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static SubscriptionRepository get repository =>
      _repository ??= AdminSubscriptionRepository();
}
