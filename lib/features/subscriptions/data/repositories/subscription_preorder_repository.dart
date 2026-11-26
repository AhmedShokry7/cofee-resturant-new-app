import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionPreorderReceipt {
  const SubscriptionPreorderReceipt({
    required this.orderId,
    required this.orderNumber,
    required this.scheduledPickupAt,
  });

  final String orderId;
  final String orderNumber;
  final DateTime scheduledPickupAt;

  factory SubscriptionPreorderReceipt.fromDatabase(Map<String, dynamic> row) {
    final map = Db.asMap(row);
    final orderId = Db.text(map['order_id']);
    final orderNumber = Db.text(map['order_number']);
    final scheduled = DateTime.tryParse(Db.text(map['scheduled_pickup_at']))
        ?.toLocal();
    if (orderId.isEmpty || orderNumber.isEmpty || scheduled == null) {
      throw const FormatException('Incomplete subscription preorder result.');
    }
    return SubscriptionPreorderReceipt(
      orderId: orderId,
      orderNumber: orderNumber,
      scheduledPickupAt: scheduled,
    );
  }
}

class SubscriptionPreorderRecord {
  const SubscriptionPreorderRecord({
    required this.orderId,
    required this.orderNumber,
    required this.branchName,
    required this.scheduledPickupAt,
    required this.orderStatus,
    required this.consumptionStatus,
  });

  final String orderId;
  final String orderNumber;
  final String branchName;
  final DateTime scheduledPickupAt;
  final OrderStatus orderStatus;
  final String consumptionStatus;

  String get consumptionStatusLabel => switch (consumptionStatus) {
    'reserved' => S.subscriptionPreorderReserved,
    'finalized' => S.subscriptionPreorderConsumed,
    'released' => S.subscriptionPreorderReleased,
    _ => consumptionStatus,
  };

  factory SubscriptionPreorderRecord.fromDatabase(Map<String, dynamic> row) {
    final map = Db.asMap(row);
    final scheduledAt = DateTime.tryParse(Db.text(map['scheduled_pickup_at']))
        ?.toLocal();
    if (scheduledAt == null) {
      throw const FormatException('Missing preorder pickup time.');
    }
    return SubscriptionPreorderRecord(
      orderId: Db.text(map['order_id']),
      orderNumber: Db.text(map['order_number']),
      branchName: Db.text(map['branch_name']),
      scheduledPickupAt: scheduledAt,
      orderStatus: OrderStatus.fromDatabase(Db.text(map['order_status'])),
      consumptionStatus: Db.text(map['consumption_status']),
    );
  }
}

/// Customer reads and creates preorders covered by one of their own plans.
///
/// Product and branch reads are server-filtered; order creation revalidates all
/// inputs and reserves quota in the same RPC transaction.
class SubscriptionPreorderRepository {
  const SubscriptionPreorderRepository({SupabaseClient? client, this.rpc})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  final Future<dynamic> Function(String name, Map<String, dynamic> params)? rpc;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  Future<dynamic> _call(String name, Map<String, dynamic> params) {
    final customRpc = rpc;
    if (customRpc != null) return customRpc(name, params);
    final client = _client;
    if (client == null) {
      throw StateError('Subscription preorders need a configured backend.');
    }
    if (client.auth.currentUser == null) {
      throw StateError('Sign in to place a subscription preorder.');
    }
    return client.rpc(name, params: params);
  }

  Future<List<Branch>> eligibleBranches(String subscriptionId) async {
    final rows = await _call('list_my_subscription_preorder_branches', {
      'p_subscription_id': subscriptionId,
    });
    if (rows is! List) return const [];
    final branches = <Branch>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final branch = Branch.fromDatabase(row);
      if (branch.isActive) branches.add(branch);
    }
    return branches;
  }

  Future<List<SubscriptionPreorderRecord>> history(
    String subscriptionId,
  ) async {
    final rows = await _call('list_my_subscription_preorders', {
      'p_subscription_id': subscriptionId,
    });
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          SubscriptionPreorderRecord.fromDatabase(row),
    ];
  }

  Future<List<SubscriptionPlanProduct>> eligibleProducts({
    required String subscriptionId,
    required String branchId,
  }) async {
    final rows = await _call('list_my_subscription_preorder_products', {
      'p_subscription_id': subscriptionId,
      'p_branch_id': branchId,
    });
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          SubscriptionPlanProduct.fromDatabase(row),
    ];
  }

  Future<SubscriptionPreorderReceipt> place({
    required String subscriptionId,
    required String branchId,
    required List<Map<String, dynamic>> lines,
    required String idempotencyKey,
    required DateTime scheduledPickupAt,
  }) async {
    if (lines.isEmpty) throw ArgumentError('At least one product is required.');
    if (idempotencyKey.trim().isEmpty) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey');
    }
    final response = await _call('place_subscription_preorder', {
      'p_subscription_id': subscriptionId,
      'p_branch_id': branchId,
      'p_lines': lines,
      'p_idempotency_key': idempotencyKey,
      'p_scheduled_pickup_at': scheduledPickupAt.toUtc().toIso8601String(),
    });
    final row = switch (response) {
      final List rows when rows.isNotEmpty && rows.first is Map =>
        Map<String, dynamic>.from(rows.first as Map),
      final Map map => Map<String, dynamic>.from(map),
      _ => throw const FormatException('Preorder RPC returned no order.'),
    };
    return SubscriptionPreorderReceipt.fromDatabase(row);
  }
}
