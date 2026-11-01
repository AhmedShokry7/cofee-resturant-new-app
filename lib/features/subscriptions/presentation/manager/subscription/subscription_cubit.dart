import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';

class SubscriptionState {
  const SubscriptionState({
    this.loading = false,
    this.plans = const [],
    this.subscription,
    this.error,
    this.qrToken,
  });

  final bool loading;
  final List<SubscriptionPlan> plans;
  final CustomerSubscription? subscription;
  final String? error;
  final String? qrToken;

  SubscriptionState copyWith({
    bool? loading,
    List<SubscriptionPlan>? plans,
    CustomerSubscription? subscription,
    bool clearSubscription = false,
    String? error,
    bool clearError = false,
    String? qrToken,
    bool clearQr = false,
  }) {
    return SubscriptionState(
      loading: loading ?? this.loading,
      plans: plans ?? this.plans,
      subscription: clearSubscription ? null : (subscription ?? this.subscription),
      error: clearError ? null : (error ?? this.error),
      qrToken: clearQr ? null : (qrToken ?? this.qrToken),
    );
  }

}

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit({required SubscriptionRepository repository})
      : _repository = repository,
        super(const SubscriptionState());

  final SubscriptionRepository _repository;

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
      emit(
        state.copyWith(
          loading: false,
          plans: results[0] as List<SubscriptionPlan>,
          subscription: results[1] as CustomerSubscription?,
          clearSubscription: results[1] == null,
        ),
      );
    } catch (error) {
      emit(state.copyWith(loading: false, error: error.toString()));
    }
  }

  Future<void> subscribe(SubscriptionPlan plan) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final key = DateTime.now().microsecondsSinceEpoch.toString();
      final subscription = await _repository.subscribe(
        planId: plan.id,
        idempotencyKey: key,
      );
      emit(state.copyWith(loading: false, subscription: subscription));
    } catch (error) {
      emit(state.copyWith(loading: false, error: error.toString()));
    }
  }

  Future<void> renew() async {
    final current = state.subscription;
    if (current == null) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final key = DateTime.now().microsecondsSinceEpoch.toString();
      final subscription = await _repository.renew(
        subscriptionId: current.id,
        paymentReference: 'pending-payment',
        idempotencyKey: key,
      );
      emit(state.copyWith(loading: false, subscription: subscription));
    } catch (error) {
      emit(state.copyWith(loading: false, error: error.toString()));
    }
  }

  Future<void> setAutoRenew(bool enabled) async {
    final current = state.subscription;
    if (current == null) return;
    try {
      await _repository.setAutoRenew(subscriptionId: current.id, enabled: enabled);
      emit(state.copyWith(subscription: current.copyWith(autoRenew: enabled)));
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> cancel() async {
    final current = state.subscription;
    if (current == null) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _repository.cancel(subscriptionId: current.id);
      emit(state.copyWith(loading: false, clearSubscription: true));
    } catch (error) {
      emit(state.copyWith(loading: false, error: error.toString()));
    }
  }

  Future<void> showQr() async {
    final current = state.subscription;
    if (current == null) return;
    try {
      final token = await _repository.generateQrToken(subscriptionId: current.id);
      emit(state.copyWith(qrToken: token));
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }
}
