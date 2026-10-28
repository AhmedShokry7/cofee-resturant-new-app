import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/entities/order_status_rules.dart';
import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';

class AdminOrderRepository implements OrderRepository {
  AdminOrderRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminOrder>> loadOrders() async {
    final response = await _supabase.rpc('admin_orders');
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => AdminOrder.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }
    return const <AdminOrder>[];
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _supabase.rpc(
      'admin_update_order_status',
      params: {'p_order_id': orderId, 'p_status': status},
    );
  }

  @override
  Future<OrderStatusRules?> loadStatusRules() async {
    final response = await _supabase.rpc('admin_order_status_matrix');
    if (response is! Map) return null;
    return OrderStatusRules.fromJson(response);
  }

  @override
  Future<void> updatePaymentStatus(String orderId, String paymentStatus) async {
    await _supabase.rpc(
      'admin_update_payment_status',
      params: {'p_order_id': orderId, 'p_payment_status': paymentStatus},
    );
  }

  @override
  Future<void> addOrderItem(
    String orderId,
    String productId,
    int quantity,
  ) async {
    await _supabase.rpc(
      'admin_add_order_item',
      params: {
        'p_order_id': orderId,
        'p_product_id': productId,
        'p_quantity': quantity,
      },
    );
  }

  @override
  Future<void> removeOrderItem(String orderItemId) async {
    await _supabase.rpc(
      'admin_remove_order_item',
      params: {'p_order_item_id': orderItemId},
    );
  }

  @override
  Future<void> markOrderViewed(String orderId) async {
    await _supabase.rpc(
      'admin_mark_order_viewed',
      params: {'p_order_id': orderId},
    );
  }
}
