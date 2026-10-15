import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';

class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository();

  final SupabaseClient _supa = Supabase.instance.client;

  /// Helper: convert a Dart string to a Postgres UUID literal.
  static String _uuid(String s) => 'uuid\'$s\'';

  @override
  Future<void> addItem({
    required String productId,
    required int quantity,
    required String note,
    required List<String> optionValueIds,
    required double unitPrice,
    String? bundleId,
  }) async {
    // The RPC internally calls get_or_create_cart(p_branch_id) so we don't
    // need to supply a cart_id. The server prices according to the bundle
    // proportional share when p_bundle_id is set, otherwise it uses
    // resolve_effective_price (client price is ignored for security).
    await _supa.rpc('orders.upsert_cart_item', params: <String, dynamic>{
      'p_branch_id': DbValues.branchId,
      'p_product_id': productId,
      'p_quantity': quantity,
      'p_note': note,
      'p_option_value_ids': optionValueIds.map(_uuid).toList(),
      'p_bundle_id': bundleId != null ? _uuid(bundleId) : null,
    });
  }

  @override
  Future getCartSummary() async {
    // Rebuild cart from server lines. The SQL function returns subtotal and count.
    final result = await _supa.rpc('orders.get_cart_summary', params: <String, dynamic>{
      'p_cart_id': DbValues.cartId,
    });

    // Result format from the SQL function: subtotal, item_count
    final subtotal = (result[0] as num).toDouble();
    final itemCount = (result[1] as num).toInt();

    // Return basic cart summary - the CartCubit manages its own state
    return {'subtotal': subtotal, 'itemCount': itemCount};
  }

  @override
  Future<void> clearCart() async {
    await _supa.rpc('orders.remove_all_cart_items', params: <String, dynamic>{
      'p_cart_id': DbValues.cartId,
    });
  }

  @override
  Future<void> removeItem(String lineId) async {
    // Parse the lineId format: 'productId::note::optionValueIds'
    final parts = lineId.split('::');
    if (parts.length < 2) return;
    final productId = parts[0];
    // Simplified removal - in a full implementation would need the cart item ID
    await _supa.rpc('orders.remove_cart_item', params: <String, dynamic>{
      'p_cart_item_id': productId,
    });
  }
}