import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/features/subscription_plans_admin/di/subscription_plans_admin_dependencies.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/repositories/subscription_plan_repository.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/usecases/load_plans.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/usecases/load_product_options.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/usecases/save_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/usecases/set_active.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/manager/admin_subscription_plan_state.dart';

class AdminSubscriptionPlanCubit extends Cubit<AdminSubscriptionPlanState> {
  AdminSubscriptionPlanCubit({SubscriptionPlanRepository? repository})
    : this._withUseCases(
        repository ?? SubscriptionPlansAdminDependencies.repository,
      );

  AdminSubscriptionPlanCubit._withUseCases(
    SubscriptionPlanRepository repository,
  ) : _repository = repository,
      _loadPlans = LoadPlansUseCase(repository),
      _loadProductOptions = LoadProductOptionsUseCase(repository),
      _savePlan = SavePlanUseCase(repository),
      _setActive = SetActiveUseCase(repository),
      super(const AdminSubscriptionPlanState());

  final SubscriptionPlanRepository _repository;
  final LoadPlansUseCase _loadPlans;
  final LoadProductOptionsUseCase _loadProductOptions;
  final SavePlanUseCase _savePlan;
  final SetActiveUseCase _setActive;

  Future<void> load() async {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: AdminSubscriptionPlanStatus.loading,
        clearError: true,
      ),
    );
    try {
      final plans = await _loadPlans();
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
          errorMessage: adminErrorMessage(error),
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
      final options = await _loadProductOptions();
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
          productOptionsError: adminErrorMessage(error),
        ),
      );
    }
  }

  Future<SubscriptionPlanSaveOutcome> savePlan(
    AdminSubscriptionPlanDraft draft,
  ) async {
    try {
      final outcome = await _savePlan(draft);
      if (outcome == SubscriptionPlanSaveOutcome.saved) await load();
      return outcome;
    } catch (_) {
      return SubscriptionPlanSaveOutcome.failed;
    }
  }

  Future<bool> setActive(String planId, bool active) async {
    try {
      final changed = await _setActive(planId, active);
      if (changed) await load();
      return changed;
    } catch (_) {
      return false;
    }
  }

  Future<void> updatePlanImage(String planId, String? imageUrl) async {
    await _repository.updatePlanImage(planId, imageUrl);
    _replacePlanImage(planId, imageUrl);
  }

  Future<String> uploadPlanImage({
    required String planId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final url = await _repository.uploadPlanImage(
      planId: planId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    _replacePlanImage(planId, url);
    return url;
  }

  Future<void> deletePlanImageFile(String? imageUrl) =>
      _repository.deletePlanImageFile(imageUrl);

  void _replacePlanImage(String planId, String? imageUrl) {
    emit(
      state.copyWith(
        plans: state.plans
            .map(
              (plan) => plan.id != planId
                  ? plan
                  : plan.copyWith(
                      imageUrl: imageUrl,
                      clearImageUrl: imageUrl == null || imageUrl.isEmpty,
                    ),
            )
            .toList(growable: false),
      ),
    );
  }
}
