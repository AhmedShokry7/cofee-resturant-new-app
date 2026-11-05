import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_usage.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/shared/utils/idempotency_key.dart';

part 'subscription_state.dart';

/// The customer's coffee subscription: the plans on sale, the active one and
/// the QR pass that spends it.
class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit({required this._repository, String? branchId})
    : _selectedBranchId = branchId,
      super(const SubscriptionState());

  final SubscriptionRepository _repository;

  /// The branch the plans are priced and sold for.
  ///
  /// `subscriptions.list_plans` filters on it (083), and the branch selector
  /// lives on the shell under these pages, so it is state the cubit has to hold
  /// rather than a value each read is handed.
  String? _selectedBranchId;

  /// Moves the page to another branch and re-reads what that branch sells.
  ///
  /// The same branch answers without a request: a rebuild that does not change
  /// the choice must not flash the grid.
  Future<void> setBranch(String? branchId) {
    if (branchId == _selectedBranchId) return Future.value();
    _selectedBranchId = branchId;
    return load();
  }

  /// One idempotency key per intended mutation, kept until it succeeds.
  ///
  /// A fresh key on every attempt made a retry after a timeout look like a
  /// request the backend had never seen, so one tap on "Subscribe" could end
  /// with two subscriptions.
  final Map<String, String> _idempotencyKeys = {};

  String _keyFor(String intent) =>
      _idempotencyKeys.putIfAbsent(intent, IdempotencyKey.create);

  /// The newest read. Only its holder may write state, so a slow page read or a
  /// history read for a subscription the customer has already left cannot land
  /// on top of the one they are looking at.
  int _loadGeneration = 0;

  /// The plan the customer's subscription belongs to, null while the plans are
  /// not in this state.
  ///
  /// Renewing charges the plan price, and the card form shows that figure, so
  /// a caller that cannot see the plan cannot show an honest amount.
  SubscriptionPlan? get renewalPlan {
    final planId = state.subscription?.planId;
    if (planId == null) return null;
    for (final plan in state.plans) {
      if (plan.id == planId) return plan;
    }
    return null;
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(loading: true, clearLoadError: true));
    try {
      final results = await Future.wait([
        _repository.plans(branchId: _selectedBranchId),
        _repository.mySubscription(),
      ]);
      if (isClosed || generation != _loadGeneration) return;
      final subscription = results[1] as CustomerSubscription?;
      emit(
        state.copyWith(
          loading: false,
          plans: results[0] as List<SubscriptionPlan>,
          subscription: subscription,
          clearSubscription: subscription == null,
          // A fresh read makes whatever pass is on screen unknown again.
          clearQr: true,
          clearQrError: true,
        ),
      );
      // The history belongs to the subscription the customer just opened the
      // page for, so it is read here instead of by another widget holding the
      // repository.
      if (subscription != null) await loadUsage(subscription.id);
    } catch (error, stackTrace) {
      if (isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(loading: false, loadError: error.toString()));
      addError(error, stackTrace);
    }
  }

  /// The cups already spent, read apart from the subscription so a failed
  /// side list cannot blank the page the customer is paying for.
  Future<void> loadUsage(String subscriptionId) async {
    final generation = _loadGeneration;
    try {
      final usage = await _repository.usageHistory(
        subscriptionId: subscriptionId,
      );
      // The names are a second read, so the answer is only held while this
      // subscription is still the one on screen.
      final named = await _namedUsage(usage);
      if (isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(usage: named, clearUsageError: true));
    } catch (error, stackTrace) {
      if (isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(usageError: error.toString()));
      addError(error, stackTrace);
    }
  }

  /// Names the usage rows using the products the plan covers.
  ///
  /// The history RPC answers with `product_id` only, so a row would otherwise
  /// be labelled with its redemption method. A failed or partial product read
  /// must not lose the history that did arrive, so the rows are returned as
  /// they are.
  Future<List<SubscriptionUsage>> _namedUsage(
    List<SubscriptionUsage> usage,
  ) async {
    if (!usage.any((entry) => entry.productId != null)) {
      return usage;
    }
    final planId = state.subscription?.planId;
    if (planId == null || planId.isEmpty) return usage;
    try {
      final products = await _repository.planProducts(planId);
      final names = {for (final p in products) p.id: p.name};
      return [
        for (final entry in usage)
          if (names[entry.productId] != null)
            entry.copyWith(productName: names[entry.productId])
          else
            entry,
      ];
    } catch (_) {
      return usage;
    }
  }

  Future<void> loadPlanProducts(String planId) async {
    try {
      final products = await _repository.planProducts(planId);
      if (isClosed) return;
      emit(
        state.copyWith(planProducts: products, clearPlanProductsError: true),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(planProductsError: error.toString()));
      addError(error, stackTrace);
    }
  }

  /// Starts a subscription and returns the row the server created.
  ///
  /// The answer is the return value, not [SubscriptionState.subscription]: the
  /// state can still hold a subscription the customer already had, and paying
  /// for a new plan against that id would charge the wrong one.
  Future<CustomerSubscription?> subscribe(SubscriptionPlan plan) async {
    if (state.isMutating) return null;
    emit(state.copyWith(isMutating: true, clearActionError: true));
    final intent = 'subscribe:${plan.id}';
    try {
      final subscription = await _repository.subscribe(
        planId: plan.id,
        idempotencyKey: _keyFor(intent),
      );
      _idempotencyKeys.remove(intent);
      if (isClosed) return null;
      // The pass belongs to the subscription that is being replaced.
      emit(
        state.copyWith(
          isMutating: false,
          subscription: subscription,
          clearQr: true,
        ),
      );
      return subscription;
    } catch (error, stackTrace) {
      if (isClosed) return null;
      emit(state.copyWith(isMutating: false, actionError: error.toString()));
      addError(error, stackTrace);
      return null;
    }
  }

  /// Renews and returns the row the server created, or null.
  ///
  /// A renewal is a new subscription with a new id, and the caller has to be
  /// able to tell that apart from the one it already had — charging the old id
  /// would pay off a cycle that is already spent.
  Future<CustomerSubscription?> renew() async {
    final current = state.subscription;
    if (current == null) return null;
    if (state.isMutating) return null;
    emit(state.copyWith(isMutating: true, clearActionError: true));
    final intent = 'renew:${current.id}';
    try {
      final subscription = await _repository.renew(
        subscriptionId: current.id,
        paymentReference: 'pending-payment',
        idempotencyKey: _keyFor(intent),
      );
      _idempotencyKeys.remove(intent);
      if (isClosed) return null;
      emit(
        state.copyWith(
          isMutating: false,
          subscription: subscription,
          clearQr: true,
        ),
      );
      return subscription;
    } catch (error, stackTrace) {
      if (isClosed) return null;
      emit(state.copyWith(isMutating: false, actionError: error.toString()));
      addError(error, stackTrace);
      return null;
    }
  }

  /// Turns the auto-renew preference on or off, answering whether it landed.
  Future<bool> setAutoRenew(bool enabled) async {
    final current = state.subscription;
    if (current == null) return false;
    try {
      await _repository.setAutoRenew(
        subscriptionId: current.id,
        enabled: enabled,
      );
      if (isClosed) return false;
      emit(state.copyWith(subscription: current.copyWith(autoRenew: enabled)));
      return true;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      // The preference is one switch on a page of facts: it fails on its own
      // line, and the subscription stays where the customer left it.
      emit(state.copyWith(actionError: error.toString()));
      addError(error, stackTrace);
      return false;
    }
  }

  /// Cancels, and reports whether the subscription is gone.
  Future<bool> cancel() async {
    final current = state.subscription;
    if (current == null) return false;
    if (state.isMutating) return false;
    emit(state.copyWith(isMutating: true, clearActionError: true));
    try {
      await _repository.cancel(subscriptionId: current.id);
      _idempotencyKeys.remove('renew:${current.id}');
      if (isClosed) return false;
      emit(
        state.copyWith(
          isMutating: false,
          clearSubscription: true,
          // A cancelled subscription has no pass to show.
          clearQr: true,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(state.copyWith(isMutating: false, actionError: error.toString()));
      addError(error, stackTrace);
      return false;
    }
  }

  /// Makes a single-use pass, and reports whether there is one to show.
  Future<bool> showQr() async {
    final current = state.subscription;
    if (current == null) return false;
    if (state.isMutating) return false;
    emit(state.copyWith(isMutating: true, clearQrError: true));
    try {
      final token = await _repository.generateQrToken(
        subscriptionId: current.id,
      );
      if (isClosed) return false;
      emit(state.copyWith(isMutating: false, qrToken: token));
      return true;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      // Whatever token was on screen belongs to a request that just failed: it
      // is single-use and five minutes old, so leaving it up invites a scan of
      // a pass the cashier will refuse.
      emit(
        state.copyWith(
          isMutating: false,
          clearQr: true,
          qrError: error.toString(),
        ),
      );
      addError(error, stackTrace);
      return false;
    }
  }
}
