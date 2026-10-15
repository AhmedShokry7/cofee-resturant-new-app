import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/loyalty/data/model/loyalty_transaction.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';

void main() {
  test('offline loyalty catalogue mirrors the seeded economy', () async {
    const repository = LoyaltyRepositoryImpl(
      catalog: MockProductRepository(),
    );

    final catalog = await repository.loadCatalog();

    expect(catalog.currencyCode, 'SAR');
    expect(catalog.rules.single.pointsPerCurrencyUnit, 1);
    expect(
      catalog.rewards.map((reward) => reward.pointsCost),
      [150, 180, 200, 250, 300, 400],
    );
    expect(
      catalog.rewards.map((reward) => reward.product.name),
      [
        'Cola',
        'Chocolate Chip Cookie',
        'Green Tea',
        'Espresso',
        'Butter Croissant',
        'Cappuccino',
      ],
    );
  });

  test('ledger rows become readable history titles', () {
    final earned = LoyaltyTransaction.fromDatabase({
      'id': 'tx-1',
      'points': 35,
      'reason': 'earn_order',
      'note': 'earned on order ORD-1',
      'balance_after': 85,
      'created_at': '2026-10-01T10:00:00Z',
    });

    expect(earned.title, 'earned on order ORD-1');
    expect(earned.balanceAfter, 85);

    final redeemed = LoyaltyTransaction.fromDatabase({
      'id': 'tx-2',
      'points': -150,
      'reason': 'redeem_reward',
      'note': '',
      'balance_after': 10,
      'created_at': '2026-10-02T10:00:00Z',
    });
    expect(redeemed.title, 'Reward redeemed');
  });

  test('guest wallet starts with a welcome bonus and persists', () async {
    SharedPreferences.setMockInitialValues({});
    const store = GuestLoyaltyWalletStore();

    final initial = await store.load();
    expect(initial.balance, 50);
    expect(initial.transactions.single.points, 50);

    await store.save(balance: 42, transactions: initial.transactions);
    final restored = await store.load();
    expect(restored.balance, 42);
  });
}
