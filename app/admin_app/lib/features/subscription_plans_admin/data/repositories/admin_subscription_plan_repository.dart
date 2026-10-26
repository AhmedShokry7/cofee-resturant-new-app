import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_product.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/repositories/subscription_plan_repository.dart';

class AdminSubscriptionPlanRepository implements SubscriptionPlanRepository {
  AdminSubscriptionPlanRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminSubscriptionPlan>> loadPlans() async {
    final response = await _supabase.rpc('admin_subscription_plans');
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (row) =>
                AdminSubscriptionPlan.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }
    return const <AdminSubscriptionPlan>[];
  }

  @override
  Future<List<AdminSubscriptionPlanProduct>> loadProductOptions() async {
    final response = await _supabase.rpc('admin_subscription_product_options');
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (row) => AdminSubscriptionPlanProduct.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
    }
    return const <AdminSubscriptionPlanProduct>[];
  }

  @override
  Future<SubscriptionPlanSaveOutcome> savePlan(
    AdminSubscriptionPlanDraft draft,
  ) async {
    final response = await _supabase.rpc(
      'admin_save_subscription_plan',
      params: {'p_plan': draft.toJson()},
    );
    if (response is! Map) return SubscriptionPlanSaveOutcome.failed;
    if (response['ok'] == true) return SubscriptionPlanSaveOutcome.saved;
    return switch ('${response['reason'] ?? ''}') {
      'duplicate_code' => SubscriptionPlanSaveOutcome.duplicateCode,
      'missing_products' => SubscriptionPlanSaveOutcome.missingProducts,
      'invalid_products' => SubscriptionPlanSaveOutcome.invalidProducts,
      'not_found' => SubscriptionPlanSaveOutcome.notFound,
      'invalid_code' ||
      'missing_name' ||
      'invalid_price' ||
      'invalid_currency' ||
      'invalid_duration' ||
      'invalid_cups' ||
      'invalid_bonus' ||
      'invalid_rollover' ||
      'invalid_renewal' ||
      'invalid_payload' => SubscriptionPlanSaveOutcome.invalidData,
      _ => SubscriptionPlanSaveOutcome.failed,
    };
  }

  @override
  Future<bool> setActive(String planId, bool active) async {
    final response = await _supabase.rpc(
      'admin_set_subscription_plan_active',
      params: {'p_plan_id': planId, 'p_active': active},
    );
    return response is Map && response['ok'] == true;
  }
}
