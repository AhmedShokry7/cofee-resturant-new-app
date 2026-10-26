import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/loyalty/data/models/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_overview.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward_draft.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_rule_draft.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_transaction.dart';
import 'package:admin_app/features/loyalty/data/repositories/admin_loyalty_repository.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_state.dart';

class AdminLoyaltyCubit extends Cubit<AdminLoyaltyState> {
  AdminLoyaltyCubit({AdminLoyaltyRepository? repository})
    : _repository = repository ?? AdminLoyaltyRepository(),
      super(const AdminLoyaltyState());

  final AdminLoyaltyRepository _repository;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(state.copyWith(status: AdminLoyaltyStatus.loading, clearError: true));
    try {
      final results = await Future.wait<Object>([
        _repository.loadOverview(),
        _repository.loadRewards(),
        _repository.loadMembers(),
        _repository.loadTransactions(),
      ]);
      final feed = results[3] as AdminLoyaltyTransactionFeed;
      emit(
        state.copyWith(
          status: AdminLoyaltyStatus.ready,
          overview: results[0] as AdminLoyaltyOverview,
          rewards: results[1] as List<AdminLoyaltyReward>,
          members: results[2] as List<AdminLoyaltyMember>,
          transactions: feed.rows,
          transactionsTotal: feed.total,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminLoyaltyStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<void> loadTargets() async {
    if (state.targetsLoading) return;
    emit(state.copyWith(targetsLoading: true, clearTargetsError: true));
    try {
      final targets = await _repository.loadTargetOptions();
      emit(
        state.copyWith(
          targets: targets,
          targetsLoading: false,
          clearTargetsError: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(targetsLoading: false, targetsError: '$error'));
    }
  }

  Future<LoyaltyRuleSaveOutcome> saveRule(AdminLoyaltyRuleDraft draft) async {
    final outcome = await _repository.saveRule(draft);
    if (outcome == LoyaltyRuleSaveOutcome.saved) {
      await load();
    }
    return outcome;
  }

  Future<LoyaltyRewardSaveOutcome> saveReward(
    AdminLoyaltyRewardDraft draft,
  ) async {
    final outcome = await _repository.saveReward(draft);
    if (outcome == LoyaltyRewardSaveOutcome.saved) {
      await load();
      await _refreshTargets();
    }
    return outcome;
  }

  Future<LoyaltyRewardMutationOutcome> setRewardActive(
    String rewardId,
    bool active,
  ) async {
    final outcome = await _repository.setRewardActive(rewardId, active);
    if (outcome == LoyaltyRewardMutationOutcome.success) {
      await load();
      await _refreshTargets();
    }
    return outcome;
  }

  Future<LoyaltyRewardMutationOutcome> deleteReward(String rewardId) async {
    final outcome = await _repository.deleteReward(rewardId);
    if (outcome == LoyaltyRewardMutationOutcome.success) {
      await load();
      await _refreshTargets();
    }
    return outcome;
  }

  Future<void> _refreshTargets() async {
    if (state.targets.isEmpty) return;
    try {
      final targets = await _repository.loadTargetOptions();
      emit(state.copyWith(targets: targets));
    } catch (_) {
      // The catalogue itself already refreshed; a stale target list is only
      // used inside the editor, which reloads it on its next open.
    }
  }
}
