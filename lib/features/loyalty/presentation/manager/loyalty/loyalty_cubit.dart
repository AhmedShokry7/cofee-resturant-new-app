import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/di/branch_cubit_binding.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/loyalty/data/model/loyalty_transaction.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

part 'loyalty_state.dart';

/// What a tap on "Redeem" ended up being.
enum RedeemOutcome {
  /// The points were spent and the reward is on its way.
  redeemed,

  /// Another tap is still being answered, so this one did nothing.
  inProgress,

  /// The wallet holds fewer points than the reward costs.
  notEnoughPoints,

  /// The reward is collected at a branch and none is chosen.
  needsBranch,

  /// A guest device wallet can only hold a product; a bundle or a plan belongs
  /// to an account.
  requiresAccount,

  /// The server refused the spend. Nothing was deducted.
  refused,
}

/// Customer loyalty wallet and redeemable catalogue.
///
/// Reference data always comes from `loyalty_rules` and `loyalty_rewards`.
/// Signed-in customers see their server ledger; guests keep a device-only
/// wallet that starts empty because there is no account for a ledger
/// to belong to.
class LoyaltyCubit extends Cubit<LoyaltyState> {
  LoyaltyCubit({
    required this._repository,
    this.branchId,
    BranchCubit? branchCubit,
  }) : super(const LoyaltyState()) {
    if (branchCubit != null) _branchBinding.bind(branchCubit, setBranch);
    // Seeded from the same source the repository reads, so restoring the
    // session that is already present is not mistaken for a switch to it.
    _identity = SupabaseService.isReady
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
        _onAuthStateChanged,
      );
    }
    load();
  }

  final LoyaltyRepository _repository;
  final BranchCubitBinding _branchBinding = BranchCubitBinding();

  /// Branch used for server-side reward redemption. Null until one is chosen.
  String? branchId;

  StreamSubscription<AuthState>? _authSubscription;

  int _counter = 0;
  String _nextId() => '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  /// Identifier of the newest load. Every load takes a number and only the one
  /// holding the latest number is allowed to write state.
  ///
  /// The wallet is replaced wholesale by whichever answer arrives, so without
  /// this a slow earlier load could land after a faster later one and put a
  /// stale balance and a stale ledger back on screen.
  int _loadGeneration = 0;

  /// Identity whose ledger is currently in state. Null means guest.
  String? _identity;

  /// Records that the signed-in customer changed and drops the previous one's
  /// wallet.
  ///
  /// Balance, transactions and lifetime points are cleared immediately, so the
  /// previous customer's points are never visible during the transition and
  /// never survive a failed read. The public earn rules, the redeemable rewards
  /// and the currency are kept: they come from reference tables that are the
  /// same for everybody and are not part of anyone's account.
  ///
  /// The device wallet is not touched, so a guest that signs back in keeps its
  /// points.
  ///
  /// Returns true when this really was a different identity. An ordinary
  /// refresh, a branch change or a token rotation leaves the wallet alone.
  @visibleForTesting
  bool applyIdentityTransition(String? identity) {
    if (identity == _identity) return false;
    _identity = identity;
    // Invalidate anything already in flight under the previous identity.
    _loadGeneration++;
    emit(
      LoyaltyState(
        balance: 0,
        transactions: const [],
        rules: state.rules,
        rewards: state.rewards,
        currencyCode: state.currencyCode,
        isGuest: true,
        isLoading: true,
      ),
    );
    return true;
  }

  /// The ledger belongs to exactly one customer, so it reloads only when the
  /// account changes.
  ///
  /// `signedIn` may be a different customer whose ledger must replace this
  /// one; `signedOut` must fall back to the guest wallet rather than keep the
  /// previous customer's balance visible. `passwordRecovery` sits with
  /// `signedIn`: GoTrue emits it instead of `signedIn` when a recovery link
  /// establishes the session, and skipping it would leave the previous
  /// customer's points on screen. `initialSession` is ignored because the auth
  /// stream replays its latest event to every new listener and the constructor
  /// load already read that same session. `tokenRefreshed` rotates a token and
  /// `userUpdated` a profile; neither moves points.
  @visibleForTesting
  bool shouldReloadOnAuthEvent(AuthState auth) =>
      auth.event == AuthChangeEvent.signedIn ||
      auth.event == AuthChangeEvent.passwordRecovery ||
      auth.event == AuthChangeEvent.signedOut;

  void _onAuthStateChanged(AuthState auth) {
    if (!shouldReloadOnAuthEvent(auth)) return;
    applyIdentityTransition(auth.session?.user.id);
    load();
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        _repository.loadCatalog(),
        _repository.loadWallet(),
        const GuestLoyaltyWalletStore().load(),
      ]);
      if (isClosed) return;
      // A newer load already asked the same question and owns the answer now.
      if (generation != _loadGeneration) return;
      final catalog = results[0] as LoyaltyCatalog;
      final wallet = results[1] as LoyaltyWallet?;
      final guest =
          results[2] as ({int balance, List<LoyaltyTransaction> transactions});

      emit(
        state.copyWith(
          rules: catalog.rules,
          rewards: catalog.rewards,
          currencyCode: catalog.currencyCode,
          balance: wallet?.balance ?? guest.balance,
          transactions: wallet?.transactions ?? guest.transactions,
          hasMoreTransactions: wallet?.hasMoreTransactions ?? false,
          lifetimePoints: wallet?.lifetimePoints ?? 0,
          tier: wallet?.tier ?? 'guest',
          isGuest: wallet == null,
          isLoading: false,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      // Same rule for failures: a stale error must not overwrite a fresh
      // balance.
      if (generation != _loadGeneration) return;
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> setBranch(String? branchId) {
    if (branchId == this.branchId) return Future.value();
    this.branchId = branchId;
    return load();
  }

  Future<void> loadMoreTransactions() async {
    if (!state.hasMoreTransactions ||
        state.isLoadingMoreTransactions ||
        state.isGuest) {
      return;
    }
    emit(state.copyWith(isLoadingMoreTransactions: true));
    try {
      final historyRepository = _repository;
      if (historyRepository is! LoyaltyTransactionHistoryRepository) {
        emit(
          state.copyWith(
            hasMoreTransactions: false,
            isLoadingMoreTransactions: false,
          ),
        );
        return;
      }
      final next =
          await (historyRepository as LoyaltyTransactionHistoryRepository)
              .loadTransactions(offset: state.transactions.length, limit: 51);
      if (isClosed) return;
      final hasMore = next.length > 50;
      emit(
        state.copyWith(
          transactions: [...state.transactions, ...next.take(50)],
          hasMoreTransactions: hasMore,
          isLoadingMoreTransactions: false,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isLoadingMoreTransactions: false));
      addError(error, stackTrace);
    }
  }

  /// +points for a completed local checkout. Returns the granted amount.
  ///
  /// This remains a device wallet until the server-backed checkout places a
  /// real order. `place_order()` is the only writer of server points, so this
  /// method deliberately does not touch the server ledger.
  Future<int> earnForOrder(
    double orderTotal, {
    int? serverPointsEarned,
    // Null rather than `S.orderPurchaseLabel`: a localized getter is not a
    // compile-time constant, so it cannot be a default value. Resolved inside
    // so it still resolves in the *current* language.
    String? title,
  }) async {
    final rule = state.rules.isEmpty ? null : state.rules.first;
    final points = serverPointsEarned ?? rule?.pointsFor(orderTotal) ?? 0;
    if (isClosed) return 0;

    if (!state.isGuest) {
      emit(state.copyWith(lastEarned: points));
      // The order RPC is the only writer of an account wallet. Refresh that
      // wallet after success so both its balance and its ledger show the
      // credit that the success screen just announced.
      await load();
      return points;
    }
    if (points <= 0) {
      emit(state.copyWith(lastEarned: 0));
      return 0;
    }

    final transaction = LoyaltyTransaction(
      id: _nextId(),
      // A reason code, because the wording then comes from `S` each time the
      // row is read and the row relabels when the customer switches language.
      // An explicit [title] is stored as a note instead, and a note wins.
      reason: 'earn_order',
      title: title ?? S.orderPurchaseLabel,
      titleAr: title,
      titleEn: title,
      points: points,
      date: DateTime.now(),
    );
    final transactions = [transaction, ...state.transactions].take(50).toList();
    emit(
      state.copyWith(
        balance: state.balance + points,
        transactions: transactions,
        lastEarned: points,
      ),
    );
    await const GuestLoyaltyWalletStore().save(
      balance: state.balance,
      transactions: state.transactions,
    );
    return points;
  }

  /// Spends points on a reward and says why it did not.
  ///
  /// Guests redeem from the device wallet. Signed-in redemption happens on the
  /// server: a product or bundle becomes a free pickup order at the chosen
  /// branch (so [branchId] is required) and a plan activates a new
  /// subscription cycle (no branch needed).
  ///
  /// The answer is an outcome rather than a `bool` because a tap that failed
  /// for the network, a tap that failed for the balance and a tap that was
  /// never sent are three different sentences to the customer — and the page
  /// used to call all of them "Not enough points".
  Future<RedeemOutcome> redeem(RewardModel reward) async {
    // A second tap while the first is unanswered would spend the same points
    // twice: `redeem_loyalty_reward` accepts no idempotency key, so this flag
    // is the only guard.
    if (state.isRedeeming) return RedeemOutcome.inProgress;
    emit(state.copyWith(isRedeeming: true, clearError: true));
    try {
      if (state.isGuest) return await _redeemGuest(reward);
      return await _redeemOnServer(reward);
    } finally {
      if (!isClosed) emit(state.copyWith(isRedeeming: false));
    }
  }

  Future<RedeemOutcome> _redeemOnServer(RewardModel reward) async {
    final rewardId = reward.id;
    if (rewardId == null || rewardId.isEmpty) return RedeemOutcome.refused;
    if (state.balance < reward.pointsCost) {
      return RedeemOutcome.notEnoughPoints;
    }
    final branch = branchId;
    if (reward.type.needsBranch && (branch == null || branch.isEmpty)) {
      return RedeemOutcome.needsBranch;
    }

    try {
      final balance = await _repository.redeemReward(
        rewardId: rewardId,
        branchId: reward.type.needsBranch ? branch : null,
      );
      if (isClosed) return RedeemOutcome.redeemed;
      emit(state.copyWith(balance: balance));
      // The spend creates an order or a subscription, so the ledger behind the
      // balance is read again rather than guessed at.
      await load();
      return RedeemOutcome.redeemed;
    } catch (error, stackTrace) {
      // The refusal is answered by the returned outcome, not by [error]: that
      // channel belongs to the wallet read, and putting a spend failure in it
      // would make the page announce the same failure twice.
      addError(error, stackTrace);
      return RedeemOutcome.refused;
    }
  }

  Future<RedeemOutcome> _redeemGuest(RewardModel reward) async {
    if (!reward.isProduct || reward.product == null) {
      return RedeemOutcome.requiresAccount;
    }
    if (state.balance < reward.pointsCost) return RedeemOutcome.notEnoughPoints;
    final transaction = LoyaltyTransaction(
      id: _nextId(),
      // The reward's two stored names, so the row says "Redeemed <reward>" in
      // whichever language the customer reads the wallet in, rather than the
      // one the tap happened in.
      reason: 'redeem_reward',
      rewardNameAr: reward.nameAr ?? reward.name,
      rewardNameEn: reward.nameEn ?? reward.name,
      title: S.redeemedReward(reward.name),
      points: -reward.pointsCost,
      date: DateTime.now(),
    );
    final transactions = [transaction, ...state.transactions].take(50).toList();
    emit(
      state.copyWith(
        balance: state.balance - reward.pointsCost,
        transactions: transactions,
      ),
    );
    await const GuestLoyaltyWalletStore().save(
      balance: state.balance,
      transactions: state.transactions,
    );
    return RedeemOutcome.redeemed;
  }

  @override
  Future<void> close() async {
    _authSubscription?.cancel();
    _authSubscription = null;
    await _branchBinding.close();
    await super.close();
  }
}
