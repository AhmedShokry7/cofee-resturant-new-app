import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_overview.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward_draft.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_rule_draft.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_transaction.dart';
import 'package:admin_app/features/loyalty/di/loyalty_dependencies.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:admin_app/features/loyalty/domain/usecases/delete_reward.dart';
import 'package:admin_app/features/loyalty/domain/usecases/load_members.dart';
import 'package:admin_app/features/loyalty/domain/usecases/load_overview.dart';
import 'package:admin_app/features/loyalty/domain/usecases/load_rewards.dart';
import 'package:admin_app/features/loyalty/domain/usecases/load_target_options.dart';
import 'package:admin_app/features/loyalty/domain/usecases/load_transactions.dart';
import 'package:admin_app/features/loyalty/domain/usecases/save_reward.dart';
import 'package:admin_app/features/loyalty/domain/usecases/save_rule.dart';
import 'package:admin_app/features/loyalty/domain/usecases/set_reward_active.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_state.dart';

class AdminLoyaltyCubit extends Cubit<AdminLoyaltyState> {
  AdminLoyaltyCubit({LoyaltyRepository? repository})
    : this._withUseCases(repository ?? LoyaltyDependencies.repository);

  AdminLoyaltyCubit._withUseCases(LoyaltyRepository repository)
    : _loadOverview = LoadOverviewUseCase(repository),
      _loadRewards = LoadRewardsUseCase(repository),
      _loadTargetOptions = LoadTargetOptionsUseCase(repository),
      _loadMembers = LoadMembersUseCase(repository),
      _loadTransactions = LoadTransactionsUseCase(repository),
      _saveRule = SaveRuleUseCase(repository),
      _saveReward = SaveRewardUseCase(repository),
      _setRewardActive = SetRewardActiveUseCase(repository),
      _deleteReward = DeleteRewardUseCase(repository),
      super(const AdminLoyaltyState());

  final LoadOverviewUseCase _loadOverview;
  final LoadRewardsUseCase _loadRewards;
  final LoadTargetOptionsUseCase _loadTargetOptions;
  final LoadMembersUseCase _loadMembers;
  final LoadTransactionsUseCase _loadTransactions;
  final SaveRuleUseCase _saveRule;
  final SaveRewardUseCase _saveReward;
  final SetRewardActiveUseCase _setRewardActive;
  final DeleteRewardUseCase _deleteReward;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(state.copyWith(status: AdminLoyaltyStatus.loading, clearError: true));
    try {
      final results = await Future.wait<Object>([
        _loadOverview(),
        _loadRewards(),
        _loadMembers(),
        _loadTransactions(),
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
      final targets = await _loadTargetOptions();
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
    final outcome = await _saveRule(draft);
    if (outcome == LoyaltyRuleSaveOutcome.saved) {
      await load();
    }
    return outcome;
  }

  Future<LoyaltyRewardSaveOutcome> saveReward(
    AdminLoyaltyRewardDraft draft,
  ) async {
    final outcome = await _saveReward(draft);
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
    final outcome = await _setRewardActive(rewardId, active);
    if (outcome == LoyaltyRewardMutationOutcome.success) {
      await load();
      await _refreshTargets();
    }
    return outcome;
  }

  Future<LoyaltyRewardMutationOutcome> deleteReward(String rewardId) async {
    final outcome = await _deleteReward(rewardId);
    if (outcome == LoyaltyRewardMutationOutcome.success) {
      await load();
      await _refreshTargets();
    }
    return outcome;
  }

  Future<void> _refreshTargets() async {
    if (state.targets.isEmpty) return;
    try {
      final targets = await _loadTargetOptions();
      emit(state.copyWith(targets: targets));
    } catch (_) {
      // The catalogue itself already refreshed; a stale target list is only
      // used inside the editor, which reloads it on its next open.
    }
  }
}
