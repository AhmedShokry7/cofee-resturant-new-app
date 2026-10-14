import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/loyalty/data/loyalty_rules.dart';
import 'package:new_coffee/features/loyalty/data/model/loyalty_transaction.dart';
import 'package:new_coffee/features/loyalty/data/rewards_list.dart';

part 'loyalty_state.dart';

/// Loyalty wallet: balance + history, persisted locally.
/// Earn on every paid order, spend by redeeming reward products.
class LoyaltyCubit extends Cubit<LoyaltyState> {
  LoyaltyCubit() : super(const LoyaltyState());

  static const _storageKey = 'loyalty_wallet_v1';
  static const _maxHistory = 50;

  int _counter = 0;
  String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  Future<void> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty) {
        _grantWelcomeBonus();
        return;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final transactions = (json['transactions'] as List?)
              ?.map(LoyaltyTransaction.fromJson)
              .whereType<LoyaltyTransaction>()
              .toList() ??
          [];
      if (isClosed) return;
      emit(
        LoyaltyState(
          balance: (json['balance'] as num?)?.toInt() ?? 0,
          transactions: transactions,
        ),
      );
    } catch (_) {
      // Wallet is best-effort: start empty rather than crash.
    }
  }

  void _grantWelcomeBonus() {
    if (isClosed) return;
    emit(
      LoyaltyState(
        balance: LoyaltyRules.welcomeBonus,
        transactions: [
          LoyaltyTransaction(
            id: _nextId(),
            title: 'Welcome bonus',
            points: LoyaltyRules.welcomeBonus,
            date: DateTime.now(),
          ),
        ],
      ),
    );
    _persist();
  }

  /// +points for a paid order total. Returns the granted amount.
  int earnForOrder(double orderTotal, {String title = 'Order purchase'}) {
    final points = LoyaltyRules.pointsFor(orderTotal);
    if (points <= 0 || isClosed) return 0;
    emit(
      LoyaltyState(
        balance: state.balance + points,
        transactions: _prepend(
          LoyaltyTransaction(
            id: _nextId(),
            title: title,
            points: points,
            date: DateTime.now(),
          ),
        ),
        lastEarned: points,
      ),
    );
    _persist();
    return points;
  }

  /// Spends points on a reward. Returns false when the balance is short.
  bool redeem(RewardModel reward) {
    if (state.balance < reward.pointsCost || isClosed) return false;
    emit(
      LoyaltyState(
        balance: state.balance - reward.pointsCost,
        transactions: _prepend(
          LoyaltyTransaction(
            id: _nextId(),
            title: 'Redeemed ${reward.product.name}',
            points: -reward.pointsCost,
            date: DateTime.now(),
          ),
        ),
      ),
    );
    _persist();
    return true;
  }

  List<LoyaltyTransaction> _prepend(LoyaltyTransaction transaction) {
    final updated = [transaction, ...state.transactions];
    if (updated.length > _maxHistory) {
      return updated.sublist(0, _maxHistory);
    }
    return updated;
  }

  Future<void> _persist() async {
    try {
      await SharedPref.setValue(
        key: _storageKey,
        value: jsonEncode({
          'balance': state.balance,
          'transactions': state.transactions
              .map((item) => item.toJson())
              .toList(),
        }),
      );
    } catch (_) {
      // Best-effort: never break checkout if storage fails.
    }
  }
}
