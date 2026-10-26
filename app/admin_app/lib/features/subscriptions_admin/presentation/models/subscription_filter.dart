import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';

enum SubscriptionFilter {
  all,
  active,
  expiringSoon,
  pendingPayment,
  expired,
  cancelled,
}

extension SubscriptionFilterView on SubscriptionFilter {
  String get label => switch (this) {
    SubscriptionFilter.all => S.subscriptionsFilterAll,
    SubscriptionFilter.active => S.subscriptionsFilterActive,
    SubscriptionFilter.expiringSoon => S.subscriptionsFilterExpiringSoon,
    SubscriptionFilter.pendingPayment => S.subscriptionsFilterPending,
    SubscriptionFilter.expired => S.subscriptionsFilterExpired,
    SubscriptionFilter.cancelled => S.subscriptionsFilterCancelled,
  };

  bool matches(AdminSubscription subscription) => switch (this) {
    SubscriptionFilter.all => true,
    SubscriptionFilter.active => subscription.isActive,
    SubscriptionFilter.expiringSoon => subscription.isExpiringSoon,
    SubscriptionFilter.pendingPayment => subscription.isPendingPayment,
    SubscriptionFilter.expired => subscription.isExpired,
    SubscriptionFilter.cancelled => subscription.isCancelled,
  };
}

List<AdminSubscription> filterSubscriptions(
  List<AdminSubscription> subscriptions, {
  String search = '',
  SubscriptionFilter filter = SubscriptionFilter.all,
}) {
  final query = search.trim().toLowerCase();
  return subscriptions
      .where((subscription) {
        if (!filter.matches(subscription)) return false;
        if (query.isEmpty) return true;
        final text = <String>[
          subscription.customerName ?? '',
          subscription.customerEmail ?? '',
          subscription.customerPhone ?? '',
          subscription.planNameAr ?? '',
          subscription.planNameEn ?? '',
          subscription.planCode ?? '',
          subscription.paymentReference ?? '',
          subscription.id,
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}
