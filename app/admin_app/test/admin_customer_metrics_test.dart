import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/customers/data/models/admin_customer.dart';
import 'package:admin_app/features/customers/data/models/admin_customer_metrics.dart';

void main() {
  group('AdminCustomerMetrics', () {
    test('parses every aggregate returned by the RPC', () {
      final metrics = AdminCustomerMetrics.fromJson(<String, dynamic>{
        'total_customers': 12,
        'previous_total_customers': 10,
        'new_customers': 2,
        'previous_new_customers': 3,
        'current_buyers': 4,
        'previous_buyers': 5,
        'current_spent': 400,
        'previous_spent': 250.5,
        'current_repeat_buyers': 2,
        'previous_repeat_buyers': 1,
      });

      expect(metrics.totalCustomers, 12);
      expect(metrics.previousTotalCustomers, 10);
      expect(metrics.newCustomers, 2);
      expect(metrics.previousNewCustomers, 3);
      expect(metrics.currentBuyers, 4);
      expect(metrics.previousBuyers, 5);
      expect(metrics.currentSpent, 400);
      expect(metrics.previousSpent, 250.5);
      expect(metrics.currentRepeatBuyers, 2);
      expect(metrics.previousRepeatBuyers, 1);
      expect(metrics.averageSpendCurrent, 100);
      expect(metrics.averageSpendPrevious, 50.1);
      expect(metrics.repeatRateCurrent, 0.5);
      expect(metrics.repeatRatePrevious, 0.2);
    });

    test('treats missing fields as zero', () {
      final metrics = AdminCustomerMetrics.fromJson(<String, dynamic>{});

      expect(metrics.totalCustomers, 0);
      expect(metrics.currentSpent, 0);
      expect(metrics.averageSpendCurrent, 0);
      expect(metrics.repeatRateCurrent, 0);
    });

    test('avoids dividing by zero when a month has no buyers', () {
      const metrics = AdminCustomerMetrics(
        currentBuyers: 0,
        previousBuyers: 0,
        currentSpent: 120,
        previousSpent: 80,
      );

      expect(metrics.averageSpendCurrent, 0);
      expect(metrics.averageSpendPrevious, 0);
      expect(metrics.repeatRateCurrent, 0);
      expect(metrics.repeatRatePrevious, 0);
    });
  });

  group('AdminCustomer', () {
    test('reads the last order timestamp from the customer payload', () {
      final customer = AdminCustomer.fromJson(<String, dynamic>{
        'id': 'c1',
        'full_name': 'Customer One',
        'last_order_at': '2026-10-20T09:30:00Z',
      });

      expect(customer.lastOrderAt, DateTime.utc(2026, 10, 20, 9, 30));
    });

    test('leaves the last order empty when the customer never ordered', () {
      final customer = AdminCustomer.fromJson(<String, dynamic>{'id': 'c1'});

      expect(customer.lastOrderAt, isNull);
    });
  });
}
