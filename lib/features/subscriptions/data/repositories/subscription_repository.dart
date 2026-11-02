import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_usage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SubscriptionRepository {
  Future<List<SubscriptionPlan>> plans({String? branchId});
  Future<List<SubscriptionPlanProduct>> planProducts(String planId);
  Future<CustomerSubscription?> mySubscription();
  Future<CustomerSubscription> subscribe({
    required String planId,
    required String idempotencyKey,
  });
  Future<int> reserveForOrder({
    required String orderId,
    required String subscriptionId,
    required String branchId,
    required List<Map<String, dynamic>> lines,
    required String idempotencyKey,
  });
  Future<CustomerSubscription> renew({
    required String subscriptionId,
    required String paymentReference,
    required String idempotencyKey,
  });
  Future<void> setAutoRenew({
    required String subscriptionId,
    required bool enabled,
  });
  Future<void> cancel({required String subscriptionId});
  Future<List<SubscriptionUsage>> usageHistory({String? subscriptionId});
  Future<String> generateQrToken({required String subscriptionId});
  Future<int> consumeQr({
    required String token,
    required String branchId,
    required String productId,
    int quantity = 1,
    required String idempotencyKey,
  });
}

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  @override
  Future<List<SubscriptionPlan>> plans({String? branchId}) async {
    final client = _client;
    if (client == null) {
      throw StateError('Subscriptions need a configured Supabase backend.');
    }
    final rows = await client.rpc(
      'list_subscription_plans',
      params: {
        if (branchId != null && branchId.isNotEmpty) 'p_branch_id': branchId,
      },
    );
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) SubscriptionPlan.fromDatabase(row),
    ];
  }

  @override
  Future<List<SubscriptionPlanProduct>> planProducts(String planId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client.rpc(
      'subscription_plan_products',
      params: {'p_plan_id': planId},
    );
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          SubscriptionPlanProduct.fromDatabase(row),
    ];
  }

  @override
  Future<CustomerSubscription?> mySubscription() async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return null;
    final rows = await client.rpc('my_subscription');
    if (rows is! List || rows.isEmpty || rows.first is! Map<String, dynamic>) {
      return null;
    }
    return CustomerSubscription.fromDatabase(
      rows.first as Map<String, dynamic>,
    );
  }

  @override
  Future<CustomerSubscription> subscribe({
    required String planId,
    required String idempotencyKey,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Subscriptions need a configured Supabase backend.');
    }
    await client.rpc(
      'create_pending_subscription',
      params: {'p_plan_id': planId, 'p_idempotency_key': idempotencyKey},
    );
    final subscription = await mySubscription();
    if (subscription == null) throw StateError('Subscription was not created.');
    return subscription;
  }

  @override
  Future<int> reserveForOrder({
    required String orderId,
    required String subscriptionId,
    required String branchId,
    required List<Map<String, dynamic>> lines,
    required String idempotencyKey,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Subscriptions need a configured Supabase backend.');
    }
    final result = await client.rpc(
      'reserve_subscription_for_order',
      params: {
        'p_order_id': orderId,
        'p_subscription_id': subscriptionId,
        'p_branch_id': branchId,
        'p_lines': lines,
        'p_idempotency_key': idempotencyKey,
      },
    );
    return Db.asInt(result);
  }

  @override
  Future<CustomerSubscription> renew({
    required String subscriptionId,
    required String paymentReference,
    required String idempotencyKey,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Subscriptions need a configured Supabase backend.');
    }
    final current = await mySubscription();
    if (current == null || current.id != subscriptionId) {
      throw StateError('Subscription not found.');
    }
    await client.rpc(
      'create_pending_subscription',
      params: {
        'p_plan_id': current.planId,
        'p_idempotency_key': idempotencyKey,
      },
    );
    final subscription = await mySubscription();
    if (subscription == null) throw StateError('Subscription was not renewed.');
    return subscription;
  }

  @override
  Future<void> setAutoRenew({
    required String subscriptionId,
    required bool enabled,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Subscriptions need a configured Supabase backend.');
    }
    await client.rpc(
      'set_subscription_auto_renew',
      params: {'p_subscription_id': subscriptionId, 'p_enabled': enabled},
    );
  }

  @override
  Future<void> cancel({required String subscriptionId}) async {
    final client = _client;
    if (client == null) {
      throw StateError('Subscriptions need a configured Supabase backend.');
    }
    await client.rpc(
      'cancel_subscription',
      params: {'p_subscription_id': subscriptionId},
    );
  }

  @override
  Future<List<SubscriptionUsage>> usageHistory({String? subscriptionId}) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client.rpc(
      'subscription_usage_history',
      params: {
        if (subscriptionId != null && subscriptionId.isNotEmpty)
          'p_subscription_id': subscriptionId,
      },
    );
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) SubscriptionUsage.fromDatabase(row),
    ];
  }

  @override
  Future<String> generateQrToken({required String subscriptionId}) async {
    final client = _client;
    if (client == null) {
      throw StateError('Subscriptions need a configured Supabase backend.');
    }
    final result = await client.rpc(
      'generate_subscription_qr',
      params: {'p_subscription_id': subscriptionId},
    );
    return result.toString();
  }

  @override
  Future<int> consumeQr({
    required String token,
    required String branchId,
    required String productId,
    int quantity = 1,
    required String idempotencyKey,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Subscriptions need a configured Supabase backend.');
    }
    final result = await client.rpc(
      'consume_subscription_qr',
      params: {
        'p_token': token,
        'p_branch_id': branchId,
        'p_product_id': productId,
        'p_quantity': quantity,
        'p_idempotency_key': idempotencyKey,
      },
    );
    return Db.asInt(result);
  }
}
