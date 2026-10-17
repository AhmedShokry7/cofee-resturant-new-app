import 'dart:math';

import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the caller's own orders through the read-only `public` bridge views.
///
/// Writes are never issued here: cancellation goes through the
/// `cancel_order()` SECURITY DEFINER wrapper, which also enforces ownership,
/// valid transitions, stock reversal and loyalty reversal.
class SupabaseOrdersRepository implements OrdersRepository {
  SupabaseOrdersRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  /// Returned history comfortably covers years of use without paging the UI.
  static const int _defaultLimit = 100;

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) throw const OrderSignInRequiredException();
    return user.id;
  }

  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = _defaultLimit,
  }) async {
    final userId = _requireUserId();
    final safeLimit = limit.clamp(1, 500);

    var query = _client.from('orders').select().eq('user_id', userId);
    if (status != null) {
      query = query.inFilter('status', OrderStatus.databaseValues(status));
    }
    final orderRows = List<Map<String, dynamic>>.from(
      await query.order('placed_at', ascending: false).limit(safeLimit)
          as List,
    );
    if (orderRows.isEmpty) return const [];

    final orderIds = <String>{
      for (final row in orderRows)
        if ((row['id']?.toString() ?? '').isNotEmpty)
          row['id'].toString(),
    }.toList();
    if (orderIds.isEmpty) return const [];

    final itemRows = List<Map<String, dynamic>>.from(
      await _client
          .from('order_items')
          .select()
          .inFilter('order_id', orderIds)
          .order('created_at') as List,
    );

    final ordersById = {for (final row in orderRows) row['id'].toString(): row};
    final orderPosition = {
      for (var i = 0; i < orderRows.length; i++)
        orderRows[i]['id'].toString(): i,
    };
    final lines = <OrderItemModel>[
      for (final item in itemRows)
        if (ordersById.containsKey(item['order_id']?.toString()))
          OrderItemModel.fromDatabase(
            order: ordersById[item['order_id'].toString()]!,
            item: item,
          ),
    ];

    // Keep headers in recency order and lines in creation order within a
    // header. The two queries are separate because an embedded PostgREST join
    // is an unnecessary failure point for a straight parent/child read.
    lines.sort((a, b) {
      final orderCompare = (orderPosition[a.orderId] ?? 0)
          .compareTo(orderPosition[b.orderId] ?? 0);
      if (orderCompare != 0) return orderCompare;
      final aCreated = a.createdAt?.microsecondsSinceEpoch ?? 0;
      final bCreated = b.createdAt?.microsecondsSinceEpoch ?? 0;
      return aCreated.compareTo(bCreated);
    });
    return lines;
  }

  @override
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? couponCode,
    String? note,
  }) async {
    _requireUserId();
    final branch = branchId.trim();
    if (branch.isEmpty) {
      throw ArgumentError.value(branchId, 'branchId', 'must not be empty');
    }
    if (lines.isEmpty) {
      throw ArgumentError.value(lines, 'lines', 'must not be empty');
    }

    final cartId = (await _client.rpc(
      'get_or_create_cart',
      params: <String, dynamic>{'p_branch_id': branch},
    )).toString();

    // Rebuild the caller's own active server cart so it matches the device
    // cart exactly. The cart RPCs only add, so a stale quantity could survive
    // a local decrement; emptying first makes the server cart the faithful
    // snapshot that place_order will price.
    await _client.rpc(
      'remove_all_cart_items',
      params: <String, dynamic>{'p_cart_id': cartId},
    );
    for (final line in lines) {
      final bundleId = line.bundleId?.trim() ?? '';
      await _client.rpc(
        'upsert_cart_item',
        params: <String, dynamic>{
          'p_branch_id': branch,
          'p_product_id': line.productId,
          'p_quantity': line.quantity,
          'p_note': line.note,
          'p_option_value_ids': line.optionValueIds,
          if (bundleId.isNotEmpty) 'p_bundle_id': bundleId,
        },
      );
    }

    final zoneId = deliveryZoneId?.trim() ?? '';
    final coupon = couponCode?.trim() ?? '';
    final orderNote = note?.trim() ?? '';
    final response = await _client.rpc(
      'place_order',
      params: <String, dynamic>{
        'p_cart_id': cartId,
        'p_idempotency_key': _newIdempotencyKey(),
        'p_fulfillment_type': fulfillmentType,
        if (zoneId.isNotEmpty) 'p_delivery_zone_id': zoneId,
        if (coupon.isNotEmpty) 'p_coupon_code': coupon,
        if (orderNote.isNotEmpty) 'p_note': orderNote,
      },
    );

    final rows = response is List ? response : const [];
    if (rows.isEmpty) {
      throw StateError('place_order returned no row.');
    }
    final row = Db.asMap(rows.first as Map);
    return PlacedOrder(
      orderId: Db.text(row['order_id']),
      orderNumber: Db.text(row['order_number']),
      subtotal: Db.asDouble(row['subtotal']),
      discountTotal: Db.asDouble(row['discount_total']),
      deliveryFee: Db.asDouble(row['delivery_fee']),
      taxTotal: Db.asDouble(row['tax_total']),
      grandTotal: Db.asDouble(row['grand_total']),
      pointsEarned: (row['points_earned'] as num?)?.toInt() ?? 0,
      placedAt: DateTime.now(),
    );
  }

  /// A fresh random idempotency key. `place_order` stores it under a UNIQUE
  /// constraint, so a replayed submit can never create a second order.
  static String _newIdempotencyKey() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    _requireUserId();
    if (orderId.isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'must not be empty');
    }
    await _client.rpc('cancel_order', params: {
      'p_order_id': orderId,
      if (reason?.trim().isNotEmpty ?? false) 'p_reason': reason!.trim(),
    });
  }

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async {
    _requireUserId();
    if (orderId.isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'must not be empty');
    }
    final rows = await _client
        .from('order_status_history')
        .select('from_status, to_status, note, created_at')
        .eq('order_id', orderId)
        .order('created_at') as List;
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) OrderStatusEvent.fromDatabase(row),
    ];
  }
}

/// Used when Supabase is unavailable or unconfigured.
///
/// There is deliberately no fake order history here: the old orders list
/// invented five orders from the compiled menu. An empty list is the only
/// honest offline answer for data that exists only on the server.
class LocalOrdersRepository implements OrdersRepository {
  const LocalOrdersRepository();

  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async =>
      const [];

  @override
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? couponCode,
    String? note,
  }) =>
      Future.error(
        UnsupportedError(
          'Checkout needs the order backend. Connect Supabase and sign in first.',
        ),
      );

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) =>
      Future.error(
        UnsupportedError(
          'Order cancellation needs the order backend. '
          'Connect Supabase and sign in first.',
        ),
      );

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async =>
      const [];
}
