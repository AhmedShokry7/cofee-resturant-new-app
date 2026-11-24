import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/features/subscriptions_admin/di/subscriptions_admin_dependencies.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_usage.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_options.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscriptions_admin/domain/repositories/subscription_repository.dart';
import 'package:admin_app/features/subscriptions_admin/domain/usecases/cancel_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/domain/usecases/load_subscriptions.dart';
import 'package:admin_app/features/subscriptions_admin/domain/usecases/load_usage.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/manager/admin_subscription_state.dart';

class AdminSubscriptionCubit extends Cubit<AdminSubscriptionState> {
  AdminSubscriptionCubit({SubscriptionRepository? repository})
    : this._withUseCases(
        repository ?? SubscriptionsAdminDependencies.repository,
      );

  AdminSubscriptionCubit._withUseCases(SubscriptionRepository repository)
    : _repository = repository,
      _loadSubscriptions = LoadSubscriptionsUseCase(repository),
      _loadUsage = LoadUsageUseCase(repository),
      _cancelSubscription = CancelSubscriptionUseCase(repository),
      super(const AdminSubscriptionState());

  final SubscriptionRepository _repository;
  final LoadSubscriptionsUseCase _loadSubscriptions;
  final LoadUsageUseCase _loadUsage;
  final CancelSubscriptionUseCase _cancelSubscription;

  Future<void> load() async {
    if (isClosed) return;
    emit(
      state.copyWith(status: AdminSubscriptionStatus.loading, clearError: true),
    );
    try {
      final subs = await _loadSubscriptions();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AdminSubscriptionStatus.ready,
          subscriptions: subs,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AdminSubscriptionStatus.failure,
          errorMessage: adminErrorMessage(error),
        ),
      );
    }
  }

  Future<List<AdminSubscriptionUsage>> loadUsage(String subscriptionId) =>
      _loadUsage(subscriptionId);

  Future<List<AdminSubscriptionCustomer>> searchCustomers(String query) =>
      _repository.searchCustomers(query);

  Future<List<AdminSubscriptionPaymentMethod>> loadPaymentMethods() =>
      _repository.loadPaymentMethods();

  Future<List<AdminSubscriptionPlan>> loadAvailablePlans() =>
      _repository.loadAvailablePlans();

  Future<AdminCreateSubscriptionOutcome> createSubscription({
    required String customerId,
    required String planId,
    required String? paymentMethodId,
    required bool paymentConfirmed,
    required String idempotencyKey,
  }) async {
    try {
      final outcome = await _repository.createSubscription(
        customerId: customerId,
        planId: planId,
        paymentMethodId: paymentMethodId,
        paymentConfirmed: paymentConfirmed,
        idempotencyKey: idempotencyKey,
      );
      if (outcome == AdminCreateSubscriptionOutcome.created) await load();
      return outcome;
    } catch (error) {
      if (kDebugMode) debugPrint('[Subscriptions] create failed: $error');
      return AdminCreateSubscriptionOutcome.failed;
    }
  }

  Future<SubscriptionRemoveOutcome> removeSubscription(
    String subscriptionId,
  ) async {
    try {
      final outcome = await _repository.removeSubscription(subscriptionId);
      if (outcome == SubscriptionRemoveOutcome.removed) await load();
      return outcome;
    } catch (_) {
      return SubscriptionRemoveOutcome.failed;
    }
  }

  Future<SubscriptionCancelOutcome> cancelSubscription(
    String subscriptionId,
  ) async {
    try {
      final outcome = await _cancelSubscription(subscriptionId);
      if (outcome == SubscriptionCancelOutcome.cancelled) await load();
      return outcome;
    } catch (_) {
      return SubscriptionCancelOutcome.failed;
    }
  }
}
