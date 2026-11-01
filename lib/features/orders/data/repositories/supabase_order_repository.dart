import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/services/supabase_read_service.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/shared/utils/rate_limit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the caller's orders through the `public` bridge and delegates all
/// customer writes to ownership-checking server RPCs.
class SupabaseOrdersRepository
    implements OrdersRepository, CheckoutQuoteRepository {
  SupabaseOrdersRepository({
    SupabaseClient? client,
    Future<dynamic> Function(String name, Map<String, dynamic> params)? rpc,
    this.userIdProvider,
  }) : _client = client ?? SupabaseService.client,
       _rpcOverride = rpc;

  final SupabaseClient _client;
  final Future<dynamic> Function(String name, Map<String, dynamic> params)?
  _rpcOverride;
  final String? Function()? userIdProvider;

  SupabaseClient get _readClient => SupabaseReadService.read;

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) {
    final override = _rpcOverride;
    return override == null
        ? _client.rpc(name, params: params)
        : override(name, params);
  }

  /// Returned history comfortably covers years of use without paging the UI.
  static const int _defaultLimit = 100;

  String _requireUserId() {
    final userId = userIdProvider?.call() ?? _client.auth.currentUser?.id;
    if (userId == null) throw const OrderSignInRequiredException();
    return userId;
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
      await query.order('placed_at', ascending: false).limit(safeLimit) as List,
    );
    if (orderRows.isEmpty) return const [];

    final orderIds = <String>{
      for (final row in orderRows)
        if ((row['id']?.toString() ?? '').isNotEmpty) row['id'].toString(),
    }.toList();
    if (orderIds.isEmpty) return const [];

    final itemRows = List<Map<String, dynamic>>.from(
      await _readClient
              .from('order_items')
              .select()
              .inFilter('order_id', orderIds)
              .order('created_at')
          as List,
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
      final orderCompare = (orderPosition[a.orderId] ?? 0).compareTo(
        orderPosition[b.orderId] ?? 0,
      );
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
    required String idempotencyKey,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  }) => _submitOrder(
    branchId: branchId,
    lines: lines,
    idempotencyKey: idempotencyKey,
    fulfillmentType: fulfillmentType,
    deliveryZoneId: deliveryZoneId,
    addressId: addressId,
    couponCode: couponCode,
    note: note,
  );

  @override
  Future<PlacedOrder> placeOrderWithQuote({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    required double expectedTotal,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  }) => _submitOrder(
    branchId: branchId,
    lines: lines,
    idempotencyKey: idempotencyKey,
    fulfillmentType: fulfillmentType,
    deliveryZoneId: deliveryZoneId,
    addressId: addressId,
    couponCode: couponCode,
    note: note,
    expectedTotal: expectedTotal,
  );

  Future<PlacedOrder> _submitOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
    double? expectedTotal,
  }) async {
    _requireUserId();
    final branch = branchId.trim();
    if (branch.isEmpty) {
      throw ArgumentError.value(branchId, 'branchId', 'must not be empty');
    }
    if (lines.isEmpty) {
      throw ArgumentError.value(lines, 'lines', 'must not be empty');
    }
    if (idempotencyKey.trim().isEmpty) {
      throw ArgumentError.value(
        idempotencyKey,
        'idempotencyKey',
        'must not be empty',
      );
    }

    final zoneId = deliveryZoneId?.trim() ?? '';
    final addressIdValue = addressId?.trim() ?? '';
    final coupon = couponCode?.trim() ?? '';
    final orderNote = note?.trim() ?? '';
    final allowed = await RateLimitClient().check('place_order');
    if (!allowed) {
      throw StateError('place_order rate limit exceeded. Try again later.');
    }
    final response = await _rpc(
      expectedTotal == null
          ? 'place_order_with_lines'
          : 'place_order_with_quote',
      <String, dynamic>{
        'p_branch_id': branch,
        'p_lines': _cartLinePayload(lines),
        'p_idempotency_key': idempotencyKey,
        'p_fulfillment_type': fulfillmentType,
        'p_expected_total': ?expectedTotal,
        if (zoneId.isNotEmpty) 'p_delivery_zone_id': zoneId,
        if (addressIdValue.isNotEmpty) 'p_address_id': addressIdValue,
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
      productDiscountTotal: Db.asDouble(row['product_discount_total']),
    );
  }

  @override
  Future<CheckoutQuote> quoteCheckout({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String fulfillmentType,
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
  }) async {
    _requireUserId();
    final response = await _rpc('quote_checkout', <String, dynamic>{
      'p_branch_id': branchId.trim(),
      'p_lines': _cartLinePayload(lines),
      'p_fulfillment_type': fulfillmentType,
      if (deliveryZoneId?.trim().isNotEmpty ?? false)
        'p_delivery_zone_id': deliveryZoneId!.trim(),
      if (addressId?.trim().isNotEmpty ?? false)
        'p_address_id': addressId!.trim(),
      if (couponCode?.trim().isNotEmpty ?? false)
        'p_coupon_code': couponCode!.trim(),
    });
    if (response is! List || response.isEmpty || response.first is! Map) {
      throw StateError('quote_checkout returned no price.');
    }
    final row = Db.asMap(response.first as Map);
    return CheckoutQuote(
      subtotal: Db.asDouble(row['subtotal']),
      discountTotal: Db.asDouble(row['discount_total']),
      deliveryFee: Db.asDouble(row['delivery_fee']),
      taxTotal: Db.asDouble(row['tax_total']),
      grandTotal: Db.asDouble(row['grand_total']),
      currencyCode: Db.text(row['currency_code']),
      productDiscountTotal: Db.asDouble(row['product_discount_total']),
    );
  }

  /// Replaces the caller's server cart atomically with the device snapshot.
  @override
  Future<void> syncCart({
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) async {
    _requireUserId();
    final branch = branchId.trim();
    if (branch.isEmpty) {
      throw ArgumentError.value(branchId, 'branchId', 'must not be empty');
    }
    await _rebuildCart(branch: branch, lines: lines);
  }

  /// Replaces the caller's active server cart in one RPC. The server reprices
  /// and validates every line; a failure rolls the whole replacement back.
  Future<String> _rebuildCart({
    required String branch,
    required List<PlaceOrderLine> lines,
  }) async {
    final allowed = await RateLimitClient().check('replace_cart');
    if (!allowed) {
      throw StateError('replace_cart rate limit exceeded. Try again later.');
    }
    final response = await _rpc('replace_cart', <String, dynamic>{
      'p_branch_id': branch,
      'p_lines': _cartLinePayload(lines),
    });
    if (response is! List || response.isEmpty || response.first is! Map) {
      throw StateError('replace_cart returned no cart.');
    }
    final row = Map<String, dynamic>.from(response.first as Map);
    final cartId = row['cart_id']?.toString() ?? '';
    if (cartId.isEmpty) throw StateError('replace_cart returned no cart id.');
    return cartId;
  }

  static List<Map<String, dynamic>> _cartLinePayload(
    List<PlaceOrderLine> lines,
  ) => [
    for (final line in lines)
      <String, dynamic>{
        'product_id': line.productId,
        'quantity': line.quantity,
        'note': line.note,
        'option_value_ids': line.optionValueIds,
        if (line.bundleId?.trim().isNotEmpty ?? false)
          'bundle_id': line.bundleId!.trim(),
      },
  ];

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    _requireUserId();
    if (orderId.isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'must not be empty');
    }
    await _client.rpc(
      'cancel_order',
      params: {
        'p_order_id': orderId,
        if (reason?.trim().isNotEmpty ?? false) 'p_reason': reason!.trim(),
      },
    );
  }

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async {
    _requireUserId();
    if (orderId.isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'must not be empty');
    }
    final rows =
        await _readClient
                .from('order_status_history')
                .select('from_status, to_status, note, created_at')
                .eq('order_id', orderId)
                .order('created_at')
            as List;
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
  }) async => const [];

  @override
  Future<void> syncCart({
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) => Future.error(
    UnsupportedError(
      'Cart sync needs the order backend. Connect Supabase and sign in first.',
    ),
  );

  @override
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  }) => Future.error(
    UnsupportedError(
      'Checkout needs the order backend. Connect Supabase and sign in first.',
    ),
  );

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) => Future.error(
    UnsupportedError(
      'Order cancellation needs the order backend. '
      'Connect Supabase and sign in first.',
    ),
  );

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}
