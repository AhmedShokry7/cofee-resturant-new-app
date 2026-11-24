import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/admin_avatar_links.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_options.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_usage.dart';
import 'package:admin_app/features/subscriptions_admin/domain/repositories/subscription_repository.dart';

class AdminSubscriptionRepository implements SubscriptionRepository {
  AdminSubscriptionRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminSubscription>> loadSubscriptions() async {
    final response = await AdminAvatarLinks.signTree(
      await _supabase.rpc('admin_subscriptions'),
      client: _supabase,
    );
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (row) => AdminSubscription.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }
    return const <AdminSubscription>[];
  }

  @override
  Future<List<AdminSubscriptionCustomer>> searchCustomers(String query) async {
    final response = await _supabase.rpc(
      'admin_subscription_customers',
      params: {'p_search': query.trim().isEmpty ? null : query.trim()},
    );
    if (response is! List) return const <AdminSubscriptionCustomer>[];
    return response
        .whereType<Map>()
        .map(
          (row) => AdminSubscriptionCustomer.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((customer) => customer.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<AdminSubscriptionPaymentMethod>> loadPaymentMethods() async {
    final response = await _supabase.rpc('admin_subscription_payment_methods');
    if (response is! List) return const <AdminSubscriptionPaymentMethod>[];
    return response
        .whereType<Map>()
        .map(
          (row) => AdminSubscriptionPaymentMethod.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((method) => method.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<AdminSubscriptionPlan>> loadAvailablePlans() async {
    final response = await _supabase.rpc('admin_subscription_plans');
    if (response is! List) return const <AdminSubscriptionPlan>[];
    return response
        .whereType<Map>()
        .map(
          (row) =>
              AdminSubscriptionPlan.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((plan) => plan.isOnSale)
        .toList(growable: false);
  }

  @override
  Future<AdminCreateSubscriptionOutcome> createSubscription({
    required String customerId,
    required String planId,
    required String? paymentMethodId,
    required bool paymentConfirmed,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_create_paid_subscription',
        params: {
          'p_user_id': customerId,
          'p_plan_id': planId,
          'p_payment_method_id': paymentMethodId,
          'p_payment_confirmed': paymentConfirmed,
          'p_idempotency_key': idempotencyKey,
        },
      );
      if (response is! Map) return AdminCreateSubscriptionOutcome.failed;
      if (response['ok'] == true) return AdminCreateSubscriptionOutcome.created;
      return switch ('${response['reason'] ?? ''}') {
        'invalid_payload' => AdminCreateSubscriptionOutcome.invalid,
        'customer_unavailable' =>
          AdminCreateSubscriptionOutcome.customerUnavailable,
        'plan_unavailable' => AdminCreateSubscriptionOutcome.planUnavailable,
        'payment_method_required' =>
          AdminCreateSubscriptionOutcome.paymentMethodRequired,
        'payment_method_unavailable' =>
          AdminCreateSubscriptionOutcome.paymentMethodUnavailable,
        'payment_confirmation_required' =>
          AdminCreateSubscriptionOutcome.paymentConfirmationRequired,
        'idempotency_conflict' =>
          AdminCreateSubscriptionOutcome.idempotencyConflict,
        _ => AdminCreateSubscriptionOutcome.failed,
      };
    } on PostgrestException catch (error) {
      if (error.code == '42883' ||
          error.code == '42703' ||
          error.code == '42P01' ||
          error.code == 'PGRST202' ||
          error.code == 'PGRST203' ||
          error.message.contains('admin_create_paid_subscription')) {
        return AdminCreateSubscriptionOutcome.databaseNeedsUpdate;
      }
      rethrow;
    }
  }

  @override
  Future<SubscriptionRemoveOutcome> removeSubscription(
    String subscriptionId,
  ) async {
    final response = await _supabase.rpc(
      'admin_remove_subscription',
      params: {'p_subscription_id': subscriptionId},
    );
    if (response is! Map) return SubscriptionRemoveOutcome.failed;
    if (response['ok'] == true) return SubscriptionRemoveOutcome.removed;
    return switch ('${response['reason'] ?? ''}') {
      'not_found' => SubscriptionRemoveOutcome.notFound,
      'reserved_cups' => SubscriptionRemoveOutcome.reservedCups,
      _ => SubscriptionRemoveOutcome.failed,
    };
  }

  @override
  Future<List<AdminSubscriptionUsage>> loadUsage(String subscriptionId) async {
    final response = await _supabase.rpc(
      'admin_subscription_usage',
      params: {'p_subscription_id': subscriptionId},
    );
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (row) =>
                AdminSubscriptionUsage.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }
    return const <AdminSubscriptionUsage>[];
  }

  @override
  Future<SubscriptionCancelOutcome> cancelSubscription(
    String subscriptionId,
  ) async {
    final response = await _supabase.rpc(
      'admin_cancel_subscription',
      params: {'p_subscription_id': subscriptionId},
    );
    if (response is! Map) return SubscriptionCancelOutcome.failed;
    if (response['ok'] == true) return SubscriptionCancelOutcome.cancelled;
    return switch ('${response['reason'] ?? ''}') {
      'not_found' => SubscriptionCancelOutcome.notFound,
      'not_cancellable' => SubscriptionCancelOutcome.notCancellable,
      'reserved_cups' => SubscriptionCancelOutcome.reservedCups,
      _ => SubscriptionCancelOutcome.failed,
    };
  }
}
