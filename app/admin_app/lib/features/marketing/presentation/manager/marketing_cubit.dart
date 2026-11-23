import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/marketing/di/marketing_dependencies.dart';
import 'package:admin_app/features/marketing/domain/entities/marketing_entities.dart';
import 'package:admin_app/features/marketing/domain/repositories/marketing_repository.dart';
import 'package:admin_app/features/marketing/presentation/manager/marketing_state.dart';

class MarketingCubit extends Cubit<MarketingState> {
  MarketingCubit({MarketingRepository? repository})
    : _repository = repository ?? MarketingDependencies.repository,
      super(const MarketingState());

  final MarketingRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: MarketingLoadStatus.loading, error: null));
    try {
      final campaigns = await _repository.loadCampaigns();
      emit(
        state.copyWith(
          status: MarketingLoadStatus.loaded,
          campaigns: campaigns,
          overview: MarketingOverview.fromCampaigns(campaigns),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: MarketingLoadStatus.failure,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> selectCampaign(String campaignId) async {
    emit(state.copyWith(isActing: true, clearActionError: true));
    try {
      final campaign = await _repository.loadCampaign(campaignId);
      emit(state.copyWith(selectedCampaign: campaign, isActing: false));
    } catch (e) {
      emit(state.copyWith(isActing: false, actionError: e.toString()));
    }
  }

  Future<void> loadDelivery(String executionId) async {
    try {
      final recipients = await _repository.loadRecipients(executionId);
      final attempts = await _repository.loadAttempts(executionId);
      emit(state.copyWith(recipients: recipients, attempts: attempts));
    } catch (e) {
      emit(state.copyWith(actionError: e.toString()));
    }
  }

  Future<void> loadConsents(String userId) async {
    try {
      final consents = await _repository.loadConsents(userId);
      emit(state.copyWith(consents: consents));
    } catch (e) {
      emit(state.copyWith(actionError: e.toString()));
    }
  }

  Future<bool> _act(Future<void> Function() action) async {
    emit(state.copyWith(isActing: true, clearActionError: true));
    try {
      await action();
      emit(state.copyWith(isActing: false));
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(isActing: false, actionError: e.toString()));
      return false;
    }
  }

  Future<void> createCampaign({
    required String name,
    required String channel,
    required String purpose,
  }) => _act(
    () => _repository.createCampaign(
      name: name,
      channel: channel,
      purpose: purpose,
    ),
  );

  Future<void> createVersion({
    required String campaignId,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
  }) => _act(
    () => _repository.createVersion(
      campaignId: campaignId,
      titleAr: titleAr,
      titleEn: titleEn,
      bodyAr: bodyAr,
      bodyEn: bodyEn,
    ),
  );

  Future<void> submitForReview(String campaignId) =>
      _act(() => _repository.submitForReview(campaignId));

  Future<void> approve(String campaignId) =>
      _act(() => _repository.approve(campaignId));

  Future<void> returnToDraft(String campaignId) =>
      _act(() => _repository.returnToDraft(campaignId));

  Future<void> schedule(String campaignId, DateTime scheduledFor) =>
      _act(() => _repository.schedule(campaignId, scheduledFor));

  Future<void> cancel(String campaignId) =>
      _act(() => _repository.cancel(campaignId));

  Future<void> pauseExecution(String executionId) =>
      _act(() => _repository.pauseExecution(executionId));

  Future<void> resumeExecution(String executionId) =>
      _act(() => _repository.resumeExecution(executionId));

  void clearActionError() => emit(state.copyWith(clearActionError: true));
}
