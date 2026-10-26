import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';

/// The figures the subscription plans page summarises above the directory.
class AdminSubscriptionPlanMetrics {
  const AdminSubscriptionPlanMetrics({
    required this.total,
    required this.onSale,
    required this.paused,
    required this.activeSubscribers,
    required this.autoRenewPlans,
  });

  factory AdminSubscriptionPlanMetrics.from(List<AdminSubscriptionPlan> plans) {
    var onSale = 0;
    var paused = 0;
    var activeSubscribers = 0;
    var autoRenewPlans = 0;
    for (final plan in plans) {
      if (plan.isOnSale) onSale++;
      if (plan.isPaused) paused++;
      activeSubscribers += plan.activeSubscribers;
      if (plan.autoRenewSupported) autoRenewPlans++;
    }
    return AdminSubscriptionPlanMetrics(
      total: plans.length,
      onSale: onSale,
      paused: paused,
      activeSubscribers: activeSubscribers,
      autoRenewPlans: autoRenewPlans,
    );
  }

  final int total;
  final int onSale;
  final int paused;
  final int activeSubscribers;
  final int autoRenewPlans;
}
