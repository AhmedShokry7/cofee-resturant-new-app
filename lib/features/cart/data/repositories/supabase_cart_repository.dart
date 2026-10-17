import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';

/// Mirrors the device cart into the signed-in customer's server cart.
///
/// Every call resolves ownership on the server via `auth.uid()`: the client
/// never supplies a user or cart id, so one customer can never touch
/// another's cart. Guests and branch-less writes stay local-only.
class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository();

  final SupabaseClient _supa = Supabase.instance.client;

  bool get _signedIn => _supa.auth.currentSession != null;

  @override
  Future<void> addItem({
    required String productId,
    required int quantity,
    required String note,
    required List<String> optionValueIds,
    required double unitPrice,
    String? bundleId,
    String? branchId,
  }) async {
    final branch = branchId?.trim() ?? '';
    if (!_signedIn || branch.isEmpty) return;
    // UUID strings travel as a JSON array; PostgREST casts them to uuid[].
    // Never format them as `uuid'...'` SQL literals: that cast fails.
    await _supa.rpc(
      'upsert_cart_item',
      params: <String, dynamic>{
        'p_branch_id': branch,
        'p_product_id': productId,
        'p_quantity': quantity,
        'p_note': note,
        'p_option_value_ids': optionValueIds,
        if (bundleId != null && bundleId.trim().isNotEmpty)
          'p_bundle_id': bundleId.trim(),
      },
    );
  }

  @override
  Future<void> clearCart({String? branchId}) async {
    final branch = branchId?.trim() ?? '';
    if (!_signedIn || branch.isEmpty) return;
    final cartId = (await _supa.rpc(
      'get_or_create_cart',
      params: <String, dynamic>{'p_branch_id': branch},
    )).toString();
    await _supa.rpc(
      'remove_all_cart_items',
      params: <String, dynamic>{'p_cart_id': cartId},
    );
  }
}
