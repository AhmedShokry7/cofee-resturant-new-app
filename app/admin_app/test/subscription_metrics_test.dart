import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_metrics.dart';

AdminSubscription _subscription({
  required String id,
  String? userId,
  String status = 'active',
  DateTime? endsAt,
}) => AdminSubscription(id: id, userId: userId, status: status, endsAt: endsAt);

void main() {
  test('empty input reports zero figures', () {
    final metrics = AdminSubscriptionMetrics.from(const []);

    expect(metrics.total, 0);
    expect(metrics.active, 0);
    expect(metrics.expiringSoon, 0);
    expect(metrics.pendingPayment, 0);
    expect(metrics.expired, 0);
    expect(metrics.cancelled, 0);
    expect(metrics.activeCustomers, 0);
  });

  test('counts every effective status from real rows', () {
    final soon = DateTime.now().add(const Duration(days: 2));
    final metrics = AdminSubscriptionMetrics.from([
      _subscription(id: 'a1', userId: 'u1', endsAt: soon),
      _subscription(id: 'a2', userId: 'u1'),
      _subscription(id: 'p1', userId: 'u2', status: 'pending_payment'),
      _subscription(id: 'e1', userId: 'u3', status: 'expired'),
      _subscription(id: 'c1', userId: 'u4', status: 'cancelled'),
    ]);

    expect(metrics.total, 5);
    expect(metrics.active, 2);
    expect(metrics.expiringSoon, 1);
    expect(metrics.pendingPayment, 1);
    expect(metrics.expired, 1);
    expect(metrics.cancelled, 1);
    // The two active subscriptions belong to the same customer.
    expect(metrics.activeCustomers, 1);
  });

  test('only active subscriptions contribute to the active customers', () {
    final metrics = AdminSubscriptionMetrics.from([
      _subscription(id: 'a1', userId: 'u1'),
      _subscription(id: 'a2', userId: 'u2'),
      _subscription(id: 'c1', userId: 'u1', status: 'cancelled'),
    ]);

    expect(metrics.active, 2);
    expect(metrics.activeCustomers, 2);
  });

  test('a subscription without a customer id still counts once', () {
    final metrics = AdminSubscriptionMetrics.from([
      _subscription(id: 'a1'),
      _subscription(id: 'a2'),
    ]);

    expect(metrics.activeCustomers, 2);
  });
}
