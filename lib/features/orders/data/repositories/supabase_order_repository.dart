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
