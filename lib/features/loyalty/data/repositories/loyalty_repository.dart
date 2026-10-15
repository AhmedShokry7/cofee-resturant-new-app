import 'dart:convert';

import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/loyalty/data/model/loyalty_transaction.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public loyalty catalogue: earn rules, redeemable rewards and currency.
class LoyaltyCatalog {
  const LoyaltyCatalog({
    this.rules = const [],
    this.rewards = const [],
    this.currencyCode = 'SAR',
  });

  final List<LoyaltyRule> rules;
  final List<RewardModel> rewards;
  final String currencyCode;

  /// Active rule with the latest validity wins, matching `place_order()`.
  LoyaltyRule? get activeRule {
    for (final rule in rules) {
      if (rule.isActive) return rule;
    }
    return null;
  }
}

/// Server-owned wallet. Null means guest/offline mode, not zero points.
class LoyaltyWallet {
  const LoyaltyWallet({
    required this.balance,
    this.lifetimePoints = 0,
    this.tier = 'bronze',
    this.transactions = const [],
  });

  final int balance;
  final int lifetimePoints;
  final String tier;
  final List<LoyaltyTransaction> transactions;
}

/// Reads loyalty reference data and, when signed in, the customer's ledger.
///
/// Guest mode intentionally keeps a device wallet: loyalty has no meaning
/// without an account on the server, but the demo checkout also has no real
/// order placement yet. Server balances are never merged with device points.
abstract class LoyaltyRepository {
  Future<LoyaltyCatalog> loadCatalog();
  Future<LoyaltyWallet?> loadWallet();
  Future<int> redeemReward({
    required String productId,
    required String branchId,
  });
}

class LoyaltyRepositoryImpl implements LoyaltyRepository {
  const LoyaltyRepositoryImpl({
    required this._catalog,
    SupabaseClient? client,
  })  : _clientOverride = client;

  final CatalogRepository _catalog;
  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  User? get _user => _client?.auth.currentUser;

  @override
  Future<LoyaltyCatalog> loadCatalog() async {
    final client = _client;
    if (client == null) return _localCatalog();

    try {
      final results = await Future.wait([
        client.from('loyalty_rules').select().eq('is_active', true),
        client.from('loyalty_rewards').select().eq('is_active', true).order(
              'points_cost',
              ascending: true,
            ),
        client.from('brand').select('currency_code').limit(1),
      ]);
      final ruleRows = (results[0] as List).cast<Map<String, dynamic>>();
      final rewardRows = (results[1] as List).cast<Map<String, dynamic>>();
      final brandRows = (results[2] as List).cast<Map<String, dynamic>>();

      final rewards = <RewardModel>[];
      for (final row in rewardRows) {
        final productId = row['product_id']?.toString();
        if (productId == null || productId.isEmpty) continue;
        final product = await _catalog.getById(productId);
        // A reward whose product disappeared is omitted. Showing its stale id
        // would let a customer attempt an impossible redemption.
        if (product == null) continue;
        rewards.add(
          RewardModel.fromDatabase(row: row, product: product),
        );
      }

      return LoyaltyCatalog(
        rules: [
          for (final row in ruleRows) LoyaltyRule.fromDatabase(row),
        ],
        rewards: rewards,
        currencyCode: brandRows.isEmpty
            ? 'SAR'
            : Db.text(brandRows.first['currency_code'], 'SAR'),
      );
    } catch (_) {
      // Catalogue reference data must degrade, not blank the loyalty screen.
      return _localCatalog();
    }
  }

  @override
  Future<LoyaltyWallet?> loadWallet() async {
    final user = _user;
    final client = _client;
    if (user == null || client == null) return null;

    final results = await Future.wait([
      client.from('user_points').select().eq('user_id', user.id).maybeSingle(),
      client
          .from('loyalty_transactions')
          .select('id, points, reason, note, balance_after, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50),
    ]);
    final account = results[0] as Map<String, dynamic>?;
    final transactionRows = (results[1] as List).cast<Map<String, dynamic>>();

    return LoyaltyWallet(
      balance: Db.asInt(account?['points_balance']),
      lifetimePoints: Db.asInt(account?['lifetime_points']),
      tier: Db.text(account?['tier'], 'bronze'),
      transactions: [
        for (final row in transactionRows)
          LoyaltyTransaction.fromDatabase(row),
      ],
    );
  }

  @override
  Future<int> redeemReward({
    required String productId,
    required String branchId,
  }) async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Sign in before redeeming a server reward.');
    }
    if (branchId.isEmpty) {
      throw ArgumentError.value(branchId, 'branchId', 'must not be empty');
    }
    final rows = await client.rpc('redeem_reward', params: {
      'p_product_id': productId,
      'p_branch_id': branchId,
    }) as List;
    if (rows.isEmpty) {
      throw StateError('Redemption returned no balance.');
    }
    return Db.asInt(rows.first);
  }

  Future<LoyaltyCatalog> _localCatalog() async {
    // Offline mirror of the seed. Kept inside the repository so the UI never
    // imports the old frozen rules directly.
    const costs = {
      '14': 150,
      '11': 180,
      '7': 200,
      '1': 250,
      '12': 300,
      '2': 400,
    };
    final rewards = <RewardModel>[];
    for (final entry in costs.entries) {
      final product = await _catalog.getById(entry.key);
      if (product == null) continue;
      rewards.add(RewardModel(product: product, pointsCost: entry.value));
    }
    rewards.sort((a, b) => a.pointsCost.compareTo(b.pointsCost));
    return LoyaltyCatalog(
      rules: const [
        LoyaltyRule(
          code: 'default_earn',
          nameAr: 'نقاط الطلب الافتراضية',
          nameEn: 'Default earn rate',
          pointsPerCurrencyUnit: 1,
        ),
      ],
      rewards: rewards,
      currencyCode: 'SAR',
    );
  }
}

/// Device wallet used only for guests and unconfigured builds.
///
/// This preserves the old demo behaviour without pretending to be the ledger.
/// It must never be added to a server balance.
class GuestLoyaltyWalletStore {
  const GuestLoyaltyWalletStore();

  static const storageKey = 'loyalty_wallet_v1';
  static const maxHistory = 50;
  static const welcomeBonus = 50;

  Future<({int balance, List<LoyaltyTransaction> transactions})> load() async {
    try {
      final raw = await SharedPref.getValue(key: storageKey);
      if (raw == null || raw.isEmpty) {
        return (
          balance: welcomeBonus,
          transactions: [
            LoyaltyTransaction(
              id: 'welcome-${DateTime.now().microsecondsSinceEpoch}',
              title: 'Welcome bonus',
              points: welcomeBonus,
              date: DateTime.now(),
            ),
          ],
        );
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        transactions: (json['transactions'] as List?)
                ?.map(LoyaltyTransaction.fromJson)
                .whereType<LoyaltyTransaction>()
                .toList() ??
            [],
      );
    } catch (_) {
      return (balance: 0, transactions: <LoyaltyTransaction>[]);
    }
  }

  Future<void> save({
    required int balance,
    required List<LoyaltyTransaction> transactions,
  }) async {
    try {
      await SharedPref.setValue(
        key: storageKey,
        value: jsonEncode({
          'balance': balance,
          'transactions': [
            for (final item in transactions.take(maxHistory)) item.toJson(),
          ],
        }),
      );
    } catch (_) {
      // Best-effort: never break checkout if storage fails.
    }
  }
}
