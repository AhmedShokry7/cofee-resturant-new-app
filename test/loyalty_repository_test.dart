import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/loyalty/data/model/loyalty_transaction.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';

void main() {
  // The default app language is Arabic; the wallet/title contract is asserted
  // in English so the expected strings are unambiguous. A separate assertion
  // below pins the Arabic title so the locale switch stays covered.
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  test('the offline catalogue is not invented: it needs a backend', () async {
    // Deliberate contract: loyalty reference data is server-owned. Without a
    // configured backend there is no fabricated reward table to fall back to.
    final repository = LoyaltyRepositoryImpl(catalog: const MockProductRepository());

    await expectLater(repository.loadCatalog(), throwsStateError);
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

    // A reason-coded row is labelled on read, so switching language relabels
    // history that was loaded in the other language.
    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(redeemed.title, S.rewardRedeemedLabel);
    expect(redeemed.title, isNot('Reward redeemed'));
  });

  test('guest wallet starts empty and persists', () async {
    SharedPreferences.setMockInitialValues({});
    const store = GuestLoyaltyWalletStore();

    final initial = await store.load();
    expect(initial.balance, 0);
    expect(initial.transactions, isEmpty);

    await store.save(balance: 42, transactions: initial.transactions);
    final restored = await store.load();
    expect(restored.balance, 42);
  });
}
