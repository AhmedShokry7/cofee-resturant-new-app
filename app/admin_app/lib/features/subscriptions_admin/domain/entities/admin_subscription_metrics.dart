import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';

/// The headline figures of the subscriptions page, derived from real rows.
class AdminSubscriptionMetrics {
  const AdminSubscriptionMetrics({
    this.total = 0,
    this.active = 0,
    this.expiringSoon = 0,
    this.pendingPayment = 0,
    this.expired = 0,
    this.cancelled = 0,
    this.activeCustomers = 0,
  });

  final int total;
  final int active;
  final int expiringSoon;
  final int pendingPayment;
  final int expired;
  final int cancelled;

  /// Unique customers holding an active subscription. It answers how many
  /// people the programme serves, not how many cups happen to be left.
  final int activeCustomers;

  factory AdminSubscriptionMetrics.from(List<AdminSubscription> subscriptions) {
    var active = 0;
    var expiringSoon = 0;
    var pendingPayment = 0;
    var expired = 0;
    var cancelled = 0;
    final activeCustomerIds = <String>{};
    for (final subscription in subscriptions) {
      switch (subscription.status) {
        case 'active':
          active++;
          final id = subscription.userId?.trim();
          activeCustomerIds.add(
            id == null || id.isEmpty ? subscription.id : id,
          );
          if (subscription.isExpiringSoon) expiringSoon++;
        case 'pending_payment':
          pendingPayment++;
        case 'expired':
          expired++;
        case 'cancelled':
          cancelled++;
      }
    }
    return AdminSubscriptionMetrics(
      total: subscriptions.length,
      active: active,
      expiringSoon: expiringSoon,
      pendingPayment: pendingPayment,
      expired: expired,
      cancelled: cancelled,
      activeCustomers: activeCustomerIds.length,
    );
  }
}
