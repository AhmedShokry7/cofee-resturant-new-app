import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_overview.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward_type.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_rule_draft.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_transaction.dart';
import 'package:admin_app/features/loyalty/presentation/models/loyalty_filters.dart';

AdminLoyaltyReward _reward({
  required String id,
  String? nameAr,
  String? nameEn,
  String? code,
  int pointsCost = 100,
  int? stockAvailable,
  bool isActive = true,
  bool isAvailable = true,
  AdminLoyaltyRewardType type = AdminLoyaltyRewardType.product,
  int redemptions = 0,
}) => AdminLoyaltyReward(
  id: id,
  type: type,
  targetId: 'target-$id',
  pointsCost: pointsCost,
  stockAvailable: stockAvailable,
  isActive: isActive,
  targetNameAr: nameAr,
  targetNameEn: nameEn,
  targetCode: code,
  targetIsAvailable: isAvailable,
  redemptionsCount: redemptions,
);

AdminLoyaltyMember _member({
  required String id,
  String? name,
  String? email,
  String? phone,
  int points = 0,
  String tier = 'bronze',
}) => AdminLoyaltyMember(
  userId: id,
  fullName: name,
  email: email,
  phone: phone,
  pointsBalance: points,
  tier: tier,
);

AdminLoyaltyTransaction _transaction({
  required String id,
  required String reason,
  int points = 20,
  String? customerName,
  String? email,
  String? orderNumber,
  String? rewardNameAr,
  String? rewardNameEn,
}) => AdminLoyaltyTransaction(
  id: id,
  userId: 'user-$id',
  points: points,
  balanceAfter: 40,
  reason: reason,
  customerName: customerName,
  customerEmail: email,
  orderNumber: orderNumber,
  rewardProductNameAr: rewardNameAr,
  rewardProductNameEn: rewardNameEn,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('loyalty overview', () {
    test('parses the current rule and the dashboard metrics', () {
      final overview = AdminLoyaltyOverview.fromJson({
        'rule': {
          'id': 'rule-1',
          'code': 'EARN',
          'name_ar': 'برنامج الكسب',
          'name_en': 'Earning program',
          'points_per_currency_unit': 1,
          'point_value': 0.05,
          'is_active': true,
          'is_current': true,
        },
        'metrics': {
          'members': 25,
          'members_with_points': 12,
          'points_outstanding': 430,
          'points_earned': 900,
          'points_redeemed': 470,
          'redemptions': 4,
          'active_rewards': 3,
          'total_rewards': 5,
          'out_of_stock_rewards': 1,
          'transactions': 20,
        },
      });

      expect(overview.hasRule, isTrue);
      expect(overview.rule!.code, 'EARN');
      expect(overview.rule!.nameFor(AppLanguage.english), 'Earning program');
      expect(overview.rule!.isCurrent, isTrue);
      expect(overview.members, 25);
      expect(overview.membersWithPoints, 12);
      expect(overview.pointsOutstanding, 430);
      expect(overview.redemptions, 4);
      expect(overview.activeRewards, 3);
      expect(overview.totalRewards, 5);
      expect(overview.outOfStockRewards, 1);
      expect(overview.transactions, 20);
    });

    test('a missing payload yields an empty program', () {
      final overview = AdminLoyaltyOverview.fromJson(const {});

      expect(overview.hasRule, isFalse);
      expect(overview.members, 0);
      expect(overview.pointsOutstanding, 0);
      expect(overview.activeRewards, 0);
      expect(overview.transactions, 0);
    });
  });

  group('loyalty rule draft', () {
    test('serializes an edited rule with its id', () {
      const draft = AdminLoyaltyRuleDraft(
        id: 'rule-1',
        pointsPerCurrencyUnit: 2.5,
        pointValue: 0.1,
        isActive: false,
      );

      expect(draft.toJson(), {
        'id': 'rule-1',
        'points_per_currency_unit': 2.5,
        'point_value': 0.1,
        'is_active': false,
      });
    });

    test('omits the id when the program is created', () {
      const draft = AdminLoyaltyRuleDraft(
        pointsPerCurrencyUnit: 1,
        pointValue: 0.05,
      );

      expect(draft.toJson(), {
        'points_per_currency_unit': 1.0,
        'point_value': 0.05,
        'is_active': true,
      });
    });
  });

  group('loyalty reward', () {
    test('parses a product-backed reward and resolves its state', () {
      final reward = AdminLoyaltyReward.fromJson({
        'id': 'reward-1',
        'reward_type': 'product',
        'product_id': 'prod-1',
        'target_id': 'prod-1',
        'points_cost': 120,
        'stock_available': null,
        'is_active': true,
        'target_name_ar': 'لاتيه',
        'target_name_en': 'Latte',
        'target_code': 'LAT-01',
        'target_price': 18,
        'target_is_active': true,
        'target_is_available': true,
        'category_name_ar': 'قهوة ساخنة',
        'category_name_en': 'Hot coffee',
        'redemptions_count': 3,
        'last_redeemed_at': '2026-05-01T10:00:00Z',
      });

      expect(reward.type, AdminLoyaltyRewardType.product);
      expect(reward.targetId, 'prod-1');
      expect(reward.pointsCost, 120);
      expect(reward.hasUnlimitedStock, isTrue);
      expect(reward.isOutOfStock, isFalse);
      expect(reward.wasRedeemed, isTrue);
      expect(reward.state, AdminLoyaltyRewardState.active);
      expect(reward.targetNameFor(AppLanguage.english), 'Latte');
      expect(reward.targetNameFor(AppLanguage.arabic), 'لاتيه');
      expect(reward.categoryNameFor(AppLanguage.english), 'Hot coffee');
      expect(reward.lastRedeemedAt, isNotNull);
    });

    test('parses bundle and plan rewards with their own target ids', () {
      final bundle = AdminLoyaltyReward.fromJson({
        'id': 'reward-2',
        'reward_type': 'bundle',
        'bundle_id': 'bundle-1',
        'target_id': 'bundle-1',
        'points_cost': 400,
        'target_name_en': 'Family box',
        'bundle_items_count': 3,
        'target_is_active': true,
        'target_is_available': true,
      });
      final plan = AdminLoyaltyReward.fromJson({
        'id': 'reward-3',
        'reward_type': 'plan',
        'plan_id': 'plan-1',
        'target_id': 'plan-1',
        'points_cost': 900,
        'target_name_en': 'Daily plan',
        'plan_duration_days': 30,
        'plan_cups_per_cycle': 10,
        'target_is_active': true,
        'target_is_available': true,
      });

      expect(bundle.type, AdminLoyaltyRewardType.bundle);
      expect(bundle.targetId, 'bundle-1');
      expect(bundle.bundleItemsCount, 3);
      expect(plan.type, AdminLoyaltyRewardType.plan);
      expect(plan.targetId, 'plan-1');
      expect(plan.planDurationDays, 30);
      expect(plan.planCupsPerCycle, 10);
    });

    test('paused, unavailable and empty stock rewards are reported', () {
      final paused = _reward(id: 'a', isActive: false);
      final unavailable = _reward(id: 'b', isAvailable: false);
      final empty = _reward(id: 'c', stockAvailable: 0);
      final available = _reward(id: 'd', stockAvailable: 4);

      expect(paused.state, AdminLoyaltyRewardState.paused);
      expect(unavailable.state, AdminLoyaltyRewardState.unavailable);
      expect(empty.state, AdminLoyaltyRewardState.outOfStock);
      expect(empty.isOutOfStock, isTrue);
      expect(available.state, AdminLoyaltyRewardState.active);
    });

    test('names fall back across languages and then to the code', () {
      final reward = _reward(
        id: 'a',
        nameAr: '',
        nameEn: 'Mocha',
        code: 'MOC-1',
      );

      expect(reward.targetNameFor(AppLanguage.arabic), 'Mocha');
      expect(
        _reward(id: 'b', code: 'ESP-1').targetNameFor(AppLanguage.english),
        'ESP-1',
      );
      expect(
        _reward(id: 'c', code: 'ESP-1').categoryNameFor(AppLanguage.arabic),
        isNull,
      );
    });
  });

  group('loyalty members and activity', () {
    test('members fall back from name to email to user id', () {
      final named = _member(
        id: 'u1',
        name: 'Mona Ali',
        email: 'mona@example.com',
        phone: '0100000000',
        points: 90,
        tier: 'gold',
      );
      final mailed = _member(id: 'u2', email: 'khaled@example.com');
      final anonymous = _member(id: 'u3');

      expect(named.displayName, 'Mona Ali');
      expect(named.contactLine, 'mona@example.com');
      expect(named.hasPoints, isTrue);
      expect(named.tier, 'gold');
      expect(mailed.displayName, 'khaled@example.com');
      expect(mailed.contactLine, isNull);
      expect(anonymous.displayName, 'u3');
      expect(anonymous.hasPoints, isFalse);
    });

    test('the activity feed parses its rows and total', () {
      final feed = AdminLoyaltyTransactionFeed.fromJson({
        'rows': [
          {
            'id': 'tx-1',
            'user_id': 'u1',
            'points': 50,
            'balance_after': 120,
            'reason': 'earn_order',
            'customer_name': 'Mona Ali',
            'order_number': 'ORD-1001',
            'created_at': '2026-05-01T10:00:00Z',
          },
          {
            'id': 'tx-2',
            'user_id': 'u2',
            'points': -100,
            'balance_after': 0,
            'reason': 'redeem_reward',
            'reward_product_name_ar': 'لاتيه',
            'reward_product_name_en': 'Latte',
            'created_at': '2026-05-02T10:00:00Z',
          },
        ],
        'total': 12,
      });

      expect(feed.total, 12);
      expect(feed.rows, hasLength(2));
      expect(feed.rows.first.isEarning, isTrue);
      expect(feed.rows.first.displayName(AppLanguage.english), 'Mona Ali');
      expect(feed.rows.last.isRedemption, isTrue);
      expect(feed.rows.last.isEarning, isFalse);
      expect(feed.rows.last.rewardProductNameFor(AppLanguage.arabic), 'لاتيه');
      expect(feed.rows.last.rewardProductNameFor(AppLanguage.english), 'Latte');
    });

    test('an empty feed stays empty', () {
      final feed = AdminLoyaltyTransactionFeed.fromJson(const {});

      expect(feed.rows, isEmpty);
      expect(feed.total, 0);
    });
  });

  group('loyalty filters', () {
    final rewards = [
      _reward(id: 'a', nameAr: 'لاتيه', nameEn: 'Latte', code: 'LAT-01'),
      _reward(id: 'b', nameEn: 'Mocha', isActive: false),
      _reward(id: 'c', nameEn: 'Tea', isAvailable: false),
      _reward(id: 'd', nameEn: 'Cake', stockAvailable: 0),
      _reward(
        id: 'e',
        nameEn: 'Family box',
        type: AdminLoyaltyRewardType.bundle,
      ),
      _reward(id: 'f', nameEn: 'Daily plan', type: AdminLoyaltyRewardType.plan),
    ];

    test('reward filters separate available, paused and empty rewards', () {
      expect(
        filterLoyaltyRewards(
          rewards,
          filter: LoyaltyRewardFilter.active,
        ).map((reward) => reward.id),
        ['a', 'e', 'f'],
      );
      expect(
        filterLoyaltyRewards(
          rewards,
          filter: LoyaltyRewardFilter.paused,
        ).map((reward) => reward.id),
        ['b', 'c'],
      );
      expect(
        filterLoyaltyRewards(
          rewards,
          filter: LoyaltyRewardFilter.outOfStock,
        ).map((reward) => reward.id),
        ['d'],
      );
      expect(filterLoyaltyRewards(rewards), rewards);
    });

    test('reward search matches names, code, category, type and status', () {
      expect(filterLoyaltyRewards(rewards, search: 'lat').single.id, 'a');
      expect(filterLoyaltyRewards(rewards, search: 'LAT-01').single.id, 'a');
      expect(filterLoyaltyRewards(rewards, search: 'لاتيه').single.id, 'a');
      expect(filterLoyaltyRewards(rewards, search: 'paused').single.id, 'b');
      expect(
        filterLoyaltyRewards(rewards, search: 'target unavailable').single.id,
        'c',
      );
      expect(filterLoyaltyRewards(rewards, search: 'bundle').single.id, 'e');
      expect(
        filterLoyaltyRewards(rewards, search: 'subscription').single.id,
        'f',
      );
    });

    test('member filters split balances and search contact details', () {
      final members = [
        _member(id: 'u1', name: 'Mona', email: 'mona@example.com', points: 90),
        _member(id: 'u2', name: 'Khaled', phone: '0100000000'),
        _member(id: 'u3', name: 'Sara', points: 12, tier: 'gold'),
      ];

      expect(
        filterLoyaltyMembers(
          members,
          filter: LoyaltyMemberFilter.withPoints,
        ).map((member) => member.userId),
        ['u1', 'u3'],
      );
      expect(
        filterLoyaltyMembers(
          members,
          filter: LoyaltyMemberFilter.noPoints,
        ).map((member) => member.userId),
        ['u2'],
      );
      expect(
        filterLoyaltyMembers(members, search: 'khaled').single.userId,
        'u2',
      );
      expect(
        filterLoyaltyMembers(members, search: 'mona@example.com').single.userId,
        'u1',
      );
      expect(filterLoyaltyMembers(members, search: '0100').single.userId, 'u2');
      expect(filterLoyaltyMembers(members, search: 'gold').single.userId, 'u3');
      expect(filterLoyaltyMembers(members, search: 'missing'), isEmpty);
    });

    test('activity filters follow the ledger reason', () {
      final transactions = [
        _transaction(
          id: 't1',
          reason: 'earn_order',
          customerName: 'Mona',
          orderNumber: 'ORD-77',
        ),
        _transaction(
          id: 't2',
          reason: 'redeem_reward',
          points: -100,
          rewardNameAr: 'لاتيه',
          rewardNameEn: 'Latte',
        ),
        _transaction(id: 't3', reason: 'adjustment'),
        _transaction(id: 't4', reason: 'expire'),
        _transaction(id: 't5', reason: 'refund', points: -20),
      ];

      expect(
        filterLoyaltyTransactions(
          transactions,
          filter: LoyaltyActivityFilter.earn,
        ).map((row) => row.id),
        ['t1'],
      );
      expect(
        filterLoyaltyTransactions(
          transactions,
          filter: LoyaltyActivityFilter.redeem,
        ).map((row) => row.id),
        ['t2'],
      );
      expect(
        filterLoyaltyTransactions(
          transactions,
          filter: LoyaltyActivityFilter.adjustment,
        ).single.id,
        't3',
      );
      expect(
        filterLoyaltyTransactions(
          transactions,
          filter: LoyaltyActivityFilter.expire,
        ).single.id,
        't4',
      );
      expect(
        filterLoyaltyTransactions(
          transactions,
          filter: LoyaltyActivityFilter.refund,
        ).single.id,
        't5',
      );
      expect(filterLoyaltyTransactions(transactions), transactions);
    });

    test('activity search matches the customer, order and reward', () {
      final transactions = [
        _transaction(
          id: 't1',
          reason: 'earn_order',
          customerName: 'Mona',
          orderNumber: 'ORD-77',
        ),
        _transaction(
          id: 't2',
          reason: 'redeem_reward',
          points: -100,
          rewardNameEn: 'Latte',
        ),
      ];

      expect(
        filterLoyaltyTransactions(transactions, search: 'mona').single.id,
        't1',
      );
      expect(
        filterLoyaltyTransactions(transactions, search: 'ord-77').single.id,
        't1',
      );
      expect(
        filterLoyaltyTransactions(transactions, search: 'latte').single.id,
        't2',
      );
      expect(
        filterLoyaltyTransactions(
          transactions,
          search: 'reward redemption',
        ).single.id,
        't2',
      );
      expect(
        filterLoyaltyTransactions(transactions, search: 'missing'),
        isEmpty,
      );
    });
  });
}
