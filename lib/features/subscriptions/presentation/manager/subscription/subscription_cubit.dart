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
  SubscriptionCubit({required this._repository})
    : super(const SubscriptionState());

  final SubscriptionRepository _repository;

  /// One idempotency key per intended mutation, kept until it succeeds.
  ///
  /// A fresh key on every attempt made a retry after a timeout look like a
  /// request the backend had never seen, so one tap on "Subscribe" could end
  /// with two subscriptions.
  final Map<String, String> _idempotencyKeys = {};

  String _keyFor(String intent) =>
      _idempotencyKeys.putIfAbsent(intent, IdempotencyKey.create);

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

  Future<void> load({String? branchId}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final results = await Future.wait([
        _repository.plans(branchId: branchId),
        _repository.mySubscription(),
      ]);
      if (isClosed) return;
      final subscription = results[1] as CustomerSubscription?;
      emit(
        state.copyWith(
          loading: false,
          plans: results[0] as List<SubscriptionPlan>,
          subscription: subscription,
          clearSubscription: subscription == null,
        ),
      );
      // The history belongs to the subscription the customer just opened the
      // page for, so it is read here instead of by another widget holding the
      // repository.
      if (subscription != null) await loadUsage(subscription.id);
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  /// The cups already spent, read apart from the subscription so a failed
  /// side list cannot blank the page the customer is paying for.
  Future<void> loadUsage(String subscriptionId) async {
    try {
      final usage = await _repository.usageHistory(
        subscriptionId: subscriptionId,
      );
      if (isClosed) return;
      emit(
        state.copyWith(usage: await _namedUsage(usage), clearUsageError: true),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
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

  Future<void> subscribe(SubscriptionPlan plan) async {
    emit(state.copyWith(loading: true, clearError: true));
    final intent = 'subscribe:${plan.id}';
    try {
      final subscription = await _repository.subscribe(
        planId: plan.id,
        idempotencyKey: _keyFor(intent),
      );
      _idempotencyKeys.remove(intent);
      if (isClosed) return;
      emit(state.copyWith(loading: false, subscription: subscription));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> renew() async {
    final current = state.subscription;
    if (current == null) return;
    emit(state.copyWith(loading: true, clearError: true));
    final intent = 'renew:${current.id}';
    try {
      final subscription = await _repository.renew(
        subscriptionId: current.id,
        paymentReference: 'pending-payment',
        idempotencyKey: _keyFor(intent),
      );
      _idempotencyKeys.remove(intent);
      if (isClosed) return;
      emit(state.copyWith(loading: false, subscription: subscription));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> setAutoRenew(bool enabled) async {
    final current = state.subscription;
    if (current == null) return;
    try {
      await _repository.setAutoRenew(
        subscriptionId: current.id,
        enabled: enabled,
      );
      if (isClosed) return;
      emit(state.copyWith(subscription: current.copyWith(autoRenew: enabled)));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> cancel() async {
    final current = state.subscription;
    if (current == null) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _repository.cancel(subscriptionId: current.id);
      _idempotencyKeys.remove('renew:${current.id}');
      if (isClosed) return;
      emit(state.copyWith(loading: false, clearSubscription: true));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> showQr() async {
    final current = state.subscription;
    if (current == null) return;
    try {
      final token = await _repository.generateQrToken(
        subscriptionId: current.id,
      );
      if (isClosed) return;
      emit(state.copyWith(qrToken: token));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: error.toString()));
      addError(error, stackTrace);
    }
  }
}
