import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/subscription_plans_admin/data/models/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/data/repositories/admin_subscription_plan_repository.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/manager/admin_subscription_plan_state.dart';

class AdminSubscriptionPlanCubit extends Cubit<AdminSubscriptionPlanState> {
  AdminSubscriptionPlanCubit({AdminSubscriptionPlanRepository? repository})
    : _repository = repository ?? AdminSubscriptionPlanRepository(),
      super(const AdminSubscriptionPlanState());

  final AdminSubscriptionPlanRepository _repository;

  Future<void> load() async {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: AdminSubscriptionPlanStatus.loading,
        clearError: true,
      ),
    );
    try {
      final plans = await _repository.loadPlans();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AdminSubscriptionPlanStatus.ready,
          plans: plans,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AdminSubscriptionPlanStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
    await loadProductOptions();
  }

  Future<void> loadProductOptions() async {
    if (isClosed) return;
    emit(
      state.copyWith(
        productOptionsLoading: true,
        clearProductOptionsError: true,
      ),
    );
    try {
      final options = await _repository.loadProductOptions();
      if (isClosed) return;
      emit(
        state.copyWith(
          productOptions: options,
          productOptionsLoading: false,
          clearProductOptionsError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          productOptionsLoading: false,
          productOptionsError: '$error',
        ),
      );
    }
  }

  Future<SubscriptionPlanSaveOutcome> savePlan(
    AdminSubscriptionPlanDraft draft,
  ) async {
    try {
      final outcome = await _repository.savePlan(draft);
      if (outcome == SubscriptionPlanSaveOutcome.saved) await load();
      return outcome;
    } catch (_) {
      return SubscriptionPlanSaveOutcome.failed;
    }
  }

  Future<bool> setActive(String planId, bool active) async {
    try {
      final changed = await _repository.setActive(planId, active);
      if (changed) await load();
      return changed;
    } catch (_) {
      return false;
    }
  }
}
