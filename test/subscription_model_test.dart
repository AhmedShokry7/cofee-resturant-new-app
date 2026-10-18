import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';

void main() {
  test('parses subscription plan from database row', () {
    final plan = SubscriptionPlan.fromDatabase({
      'id': 'plan-1',
      'code': 'gold',
      'name_ar': 'ذهبي',
      'name_en': 'Gold',
      'price': 99,
      'currency_code': 'SAR',
      'duration_days': 30,
      'cups_per_cycle': 10,
      'rollover_cap_cups': 3,
      'is_active': true,
      'is_for_sale': true,
      'all_branches': false,
      'branch_ids': ['b1'],
      'product_ids': ['p1'],
    });
    expect(plan.id, 'plan-1');
    expect(plan.cupsPerCycle, 10);
    expect(plan.rolloverCapCups, 3);
    expect(plan.branchIds, ['b1']);
    expect(plan.productIds, ['p1']);
  });

  test('calculates available cups', () {
    final sub = CustomerSubscription(
      id: 'sub-1',
      planId: 'plan-1',
      cupsEntitled: 10,
      cupsUsed: 4,
      cupsCarriedOver: 2,
    );
    expect(sub.availableCups, 8);
  });
}
