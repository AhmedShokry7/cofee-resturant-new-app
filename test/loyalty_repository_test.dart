import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/loyalty/data/model/loyalty_transaction.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
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
    final repository = LoyaltyRepositoryImpl(
      catalog: const MockProductRepository(),
    );

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

  group('reward targets', () {
    test('a product reward keeps its product id, name and picture', () {
      final reward = RewardModel.fromDatabase(
        row: {
          'id': 'reward-1',
          'reward_type': 'product',
          'product_id': 'product-1',
          'bundle_id': null,
          'plan_id': null,
          'points_cost': 150,
          'stock_available': null,
          'is_active': true,
          'name_ar': 'لاتيه',
          'name_en': 'Latte',
          'image_url': 'https://example.com/latte.jpg',
        },
      );

      expect(reward.type, RewardTargetType.product);
      expect(reward.targetId, 'product-1');
      expect(reward.isProduct, isTrue);
      expect(reward.name, 'Latte');
      expect(reward.image, 'https://example.com/latte.jpg');
      expect(reward.affordable(150), isTrue);
      expect(reward.affordable(149), isFalse);
    });

    test('bundle and plan rewards resolve their own target', () {
      final bundle = RewardModel.fromDatabase(
        row: {
          'id': 'reward-2',
          'reward_type': 'bundle',
          'product_id': null,
          'bundle_id': 'bundle-1',
          'plan_id': null,
          'points_cost': 300,
          'stock_available': 2,
          'is_active': true,
          'name_ar': 'باقة العائلة',
          'name_en': 'Family box',
          'image_url': null,
        },
      );
      final plan = RewardModel.fromDatabase(
        row: {
          'id': 'reward-3',
          'reward_type': 'plan',
          'product_id': null,
          'bundle_id': null,
          'plan_id': 'plan-1',
          'points_cost': 400,
          'stock_available': null,
          'is_active': true,
          'name_ar': 'الباقة اليومية',
          'name_en': 'Daily plan',
          'image_url': null,
        },
      );

      expect(bundle.type, RewardTargetType.bundle);
      expect(bundle.targetId, 'bundle-1');
      expect(bundle.product, isNull);
      expect(bundle.name, 'Family box');
      expect(bundle.type.needsBranch, isTrue);
      expect(plan.type, RewardTargetType.plan);
      expect(plan.targetId, 'plan-1');
      expect(plan.product, isNull);
      expect(plan.name, 'Daily plan');
      expect(plan.type.needsBranch, isFalse);
    });

    test('an exhausted reward is never affordable', () {
      final reward = RewardModel.fromDatabase(
        row: {
          'id': 'reward-4',
          'reward_type': 'plan',
          'plan_id': 'plan-1',
          'points_cost': 10,
          'stock_available': 0,
          'is_active': true,
        },
      );

      expect(reward.isOutOfStock, isTrue);
      expect(reward.affordable(1000), isFalse);
    });

    test('a row without a reward type stays a product reward', () {
      final reward = RewardModel.fromDatabase(
        row: {'id': 'reward-5', 'product_id': 'product-5', 'points_cost': 100},
      );

      expect(reward.type, RewardTargetType.product);
      expect(reward.targetId, 'product-5');
    });
  });
}
