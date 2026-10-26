import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_overview.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward_draft.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_rule_draft.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_target_option.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_transaction.dart';

enum LoyaltyRuleSaveOutcome {
  saved,
  invalidRate,
  invalidValue,
  notFound,
  failed,
}

enum LoyaltyRewardSaveOutcome {
  saved,
  duplicateTarget,
  invalidTarget,
  invalidType,
  targetUnavailable,
  invalidPoints,
  invalidStock,
  notFound,
  failed,
}

enum LoyaltyRewardMutationOutcome {
  success,
  notFound,
  hasRedemptions,
  targetUnavailable,
  failed,
}

class AdminLoyaltyRepository {
  AdminLoyaltyRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<AdminLoyaltyOverview> loadOverview() async {
    final response = await _supabase.rpc('admin_loyalty_overview');
    if (response is Map) {
      return AdminLoyaltyOverview.fromJson(Map<String, dynamic>.from(response));
    }
    return AdminLoyaltyOverview.empty;
  }

  Future<List<AdminLoyaltyReward>> loadRewards() async {
    final response = await _supabase.rpc('admin_loyalty_rewards');
    return _mapList(response, AdminLoyaltyReward.fromJson);
  }

  Future<List<AdminLoyaltyTargetOption>> loadTargetOptions() async {
    final response = await _supabase.rpc('admin_loyalty_reward_targets');
    return _mapList(response, AdminLoyaltyTargetOption.fromJson);
  }

  Future<List<AdminLoyaltyMember>> loadMembers() async {
    final response = await _supabase.rpc('admin_loyalty_members');
    return _mapList(response, AdminLoyaltyMember.fromJson);
  }

  Future<AdminLoyaltyTransactionFeed> loadTransactions({
    int limit = 300,
  }) async {
    final response = await _supabase.rpc(
      'admin_loyalty_transactions',
      params: {'p_limit': limit},
    );
    if (response is Map) {
      return AdminLoyaltyTransactionFeed.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    return AdminLoyaltyTransactionFeed.empty;
  }

  Future<LoyaltyRuleSaveOutcome> saveRule(AdminLoyaltyRuleDraft draft) async {
    final response = await _supabase.rpc(
      'admin_save_loyalty_rule',
      params: {'p_rule': draft.toJson()},
    );
    if (_isOk(response)) return LoyaltyRuleSaveOutcome.saved;
    return switch (_reason(response)) {
      'invalid_rate' => LoyaltyRuleSaveOutcome.invalidRate,
      'invalid_value' => LoyaltyRuleSaveOutcome.invalidValue,
      'not_found' => LoyaltyRuleSaveOutcome.notFound,
      _ => LoyaltyRuleSaveOutcome.failed,
    };
  }

  Future<LoyaltyRewardSaveOutcome> saveReward(
    AdminLoyaltyRewardDraft draft,
  ) async {
    final response = await _supabase.rpc(
      'admin_save_loyalty_reward',
      params: {'p_reward': draft.toJson()},
    );
    if (_isOk(response)) return LoyaltyRewardSaveOutcome.saved;
    return switch (_reason(response)) {
      'duplicate_target' => LoyaltyRewardSaveOutcome.duplicateTarget,
      'invalid_target' => LoyaltyRewardSaveOutcome.invalidTarget,
      'invalid_type' => LoyaltyRewardSaveOutcome.invalidType,
      'target_unavailable' => LoyaltyRewardSaveOutcome.targetUnavailable,
      'invalid_points' => LoyaltyRewardSaveOutcome.invalidPoints,
      'invalid_stock' => LoyaltyRewardSaveOutcome.invalidStock,
      'not_found' => LoyaltyRewardSaveOutcome.notFound,
      _ => LoyaltyRewardSaveOutcome.failed,
    };
  }

  Future<LoyaltyRewardMutationOutcome> setRewardActive(
    String rewardId,
    bool active,
  ) async {
    final response = await _supabase.rpc(
      'admin_set_loyalty_reward_active',
      params: {'p_reward_id': rewardId, 'p_active': active},
    );
    if (_isOk(response)) return LoyaltyRewardMutationOutcome.success;
    return switch (_reason(response)) {
      'not_found' => LoyaltyRewardMutationOutcome.notFound,
      'target_unavailable' => LoyaltyRewardMutationOutcome.targetUnavailable,
      _ => LoyaltyRewardMutationOutcome.failed,
    };
  }

  Future<LoyaltyRewardMutationOutcome> deleteReward(String rewardId) async {
    final response = await _supabase.rpc(
      'admin_delete_loyalty_reward',
      params: {'p_reward_id': rewardId},
    );
    if (_isOk(response)) return LoyaltyRewardMutationOutcome.success;
    return switch (_reason(response)) {
      'not_found' => LoyaltyRewardMutationOutcome.notFound,
      'has_redemptions' => LoyaltyRewardMutationOutcome.hasRedemptions,
      _ => LoyaltyRewardMutationOutcome.failed,
    };
  }

  static bool _isOk(Object? response) =>
      response is Map && response['ok'] == true;

  static String _reason(Object? response) =>
      response is Map ? '${response['reason'] ?? ''}' : '';

  static List<T> _mapList<T>(
    Object? response,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (response is! List) return <T>[];
    return response
        .whereType<Map>()
        .map((row) => fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}
