import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_preorder_repository.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';

void main() {
  test('available subscription balance excludes used and reserved cups', () {
    final subscription = CustomerSubscription(
      id: 'sub-1',
      planId: 'plan-1',
      cupsEntitled: 10,
      cupsCarriedOver: 2,
      cupsUsed: 3,
      cupsReserved: 4,
    );

    expect(subscription.availableCups, 5);
  });

  test(
    'preorder RPC receives only subscription, branch, lines, key and slot',
    () async {
      String? called;
      Map<String, dynamic>? parameters;
      final repository = SubscriptionPreorderRepository(
        rpc: (name, params) async {
          called = name;
          parameters = params;
          return [
            {
              'order_id': 'order-1',
              'order_number': 'ORD-1',
              'status': 'pending',
              'scheduled_pickup_at': '2026-11-27T08:00:00Z',
              'remaining_cups': 4,
              'cups_reserved': 2,
              'reused_existing_order': false,
            },
          ];
        },
      );

      final result = await repository.place(
        subscriptionId: 'sub-1',
        branchId: 'branch-1',
        lines: const [
          {'product_id': 'product-1', 'quantity': 2},
        ],
        idempotencyKey: 'preorder-key-1',
        scheduledPickupAt: DateTime.utc(2026, 11, 27, 8),
      );

      expect(called, 'place_subscription_preorder');
      expect(parameters, {
        'p_subscription_id': 'sub-1',
        'p_branch_id': 'branch-1',
        'p_lines': [
          {'product_id': 'product-1', 'quantity': 2},
        ],
        'p_idempotency_key': 'preorder-key-1',
        'p_scheduled_pickup_at': '2026-11-27T08:00:00.000Z',
      });
      expect(result.orderId, 'order-1');
      expect(result.orderNumber, 'ORD-1');
      expect(result.scheduledPickupAt.toUtc(), DateTime.utc(2026, 11, 27, 8));
    },
  );
}
