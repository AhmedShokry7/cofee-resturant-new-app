import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/loyalty/data/model/loyalty_transaction.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';

part 'loyalty_state.dart';

/// Customer loyalty wallet and redeemable catalogue.
///
/// Reference data always comes from `loyalty_rules` and `loyalty_rewards`.
/// Signed-in customers see their server ledger; guests keep a device-only demo
/// wallet because there is no account for the ledger to belong to.
class LoyaltyCubit extends Cubit<LoyaltyState> {
  LoyaltyCubit({
    required this._repository,
    this.branchId,
  })  : super(const LoyaltyState()) {
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService
          .client.auth.onAuthStateChange
          .listen((_) => load());
    }
    load();
  }

  final LoyaltyRepository _repository;

  /// Branch used for server-side reward redemption. Null until one is chosen.
  String? branchId;

  StreamSubscription<dynamic>? _authSubscription;

  int _counter = 0;
  String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        _repository.loadCatalog(),
        _repository.loadWallet(),
        const GuestLoyaltyWalletStore().load(),
      ]);
      if (isClosed) return;
      final catalog = results[0] as LoyaltyCatalog;
      final wallet = results[1] as LoyaltyWallet?;
      final guest = results[2]
          as ({int balance, List<LoyaltyTransaction> transactions});

      emit(state.copyWith(
        rules: catalog.rules,
        rewards: catalog.rewards,
        currencyCode: catalog.currencyCode,
        balance: wallet?.balance ?? guest.balance,
        transactions: wallet?.transactions ?? guest.transactions,
        lifetimePoints: wallet?.lifetimePoints ?? 0,
        tier: wallet?.tier ?? 'guest',
        isGuest: wallet == null,
        isLoading: false,
      ));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> setBranch(String? branchId) {
    if (branchId == this.branchId) return Future.value();
    this.branchId = branchId;
    return load();
  }

  /// +points for a completed local checkout. Returns the granted amount.
  ///
  /// This remains a device wallet until the server-backed checkout places a
  /// real order. `place_order()` is the only writer of server points, so this
  /// method deliberately does not touch the server ledger.
  Future<int> earnForOrder(double orderTotal,
      {String title = 'Order purchase'}) async {
    final rule = state.rules.isEmpty ? null : state.rules.first;
    final points = rule?.pointsFor(orderTotal) ?? 0;
    if (points <= 0 || isClosed) return 0;

    if (!state.isGuest) {
      // Show the server rule's estimate without inventing ledger rows. The
      // real credit arrives when the order itself is placed on the server.
      emit(state.copyWith(lastEarned: points));
      return points;
    }

    final transaction = LoyaltyTransaction(
      id: _nextId(),
      title: title,
      points: points,
      date: DateTime.now(),
    );
    final transactions = [transaction, ...state.transactions].take(50).toList();
    emit(state.copyWith(
      balance: state.balance + points,
      transactions: transactions,
      lastEarned: points,
    ));
    await const GuestLoyaltyWalletStore().save(
      balance: state.balance,
      transactions: state.transactions,
    );
    return points;
  }

  /// Spends points on a reward. Returns false when the balance is short.
  ///
  /// Guests redeem from the device wallet. Signed-in redemption needs a branch
  /// because the server atomically adds the reward to that branch's cart; it
  /// is therefore unavailable until branch selection exists in the UI.
  Future<bool> redeem(RewardModel reward) async {
    if (state.isGuest) return _redeemGuest(reward);
    if (reward.id == null || reward.product.id.isEmpty) return false;
    if (state.balance < reward.pointsCost || isClosed) return false;

    final branch = branchId;
    if (branch == null || branch.isEmpty) {
      emit(state.copyWith(
        error: 'Select a branch before redeeming this reward.',
      ));
      return false;
    }

    try {
      final balance = await _repository.redeemReward(
        productId: reward.product.id,
        branchId: branch,
      );
      if (isClosed) return true;
      emit(state.copyWith(balance: balance, clearError: true));
      await load();
      return true;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(state.copyWith(error: error.toString()));
      addError(error, stackTrace);
      return false;
    }
  }

  Future<bool> _redeemGuest(RewardModel reward) async {
    if (state.balance < reward.pointsCost || isClosed) return false;
    final transaction = LoyaltyTransaction(
      id: _nextId(),
      title: 'Redeemed ${reward.product.name}',
      points: -reward.pointsCost,
      date: DateTime.now(),
    );
    final transactions = [transaction, ...state.transactions].take(50).toList();
    emit(state.copyWith(
      balance: state.balance - reward.pointsCost,
      transactions: transactions,
    ));
    await const GuestLoyaltyWalletStore().save(
      balance: state.balance,
      transactions: state.transactions,
    );
    return true;
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _authSubscription = null;
    return super.close();
  }
}
