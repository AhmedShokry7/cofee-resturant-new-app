import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/cart/data/model/cart_line.dart';
import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';
import 'package:new_coffee/shared/utils/rate_limit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in customer's cart, stored in `orders.carts` / `orders.cart_items`.
///
/// Every call resolves ownership on the server: the client never supplies a
/// user or cart id, so one customer can never touch another's cart. The reads
/// go through the `public.carts` / `public.cart_items` / `public.cart_item_options`
/// bridge views, which are declared `WITH (security_invoker = true)`, so the
/// owner-only RLS policies on the underlying tables decide the rows.
///
/// Writes go through `public.replace_cart`, the same server transaction the
/// checkout already uses: it replaces the whole cart atomically, re-prices
/// every line from the catalogue and validates the option selections, and it
/// keeps the previous cart if any line is rejected.
class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository({
    SupabaseClient? client,
    Future<dynamic> Function(String name, Map<String, dynamic> params)? rpc,
  })  : _clientOverride = client,
        _rpcOverride = rpc;

  final SupabaseClient? _clientOverride;
  final Future<dynamic> Function(String name, Map<String, dynamic> params)?
      _rpcOverride;

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    if (SupabaseService.isReady) return SupabaseService.client;
    throw StateError('The cart needs a configured Supabase backend.');
  }

  bool get _signedIn => _client.auth.currentSession != null;

  @override
  Future<List<CartLine>?> fetchLines({String? branchId}) async {
    final branch = branchId?.trim() ?? '';
    // No session or no branch means there is no server cart to read. The
    // caller keeps what it has instead of reading this as an empty cart.
    if (branch.isEmpty || !_signedIn) return null;

    final cartId = await _activeCartId(branch);
    if (cartId == null || cartId.isEmpty) return const <CartLine>[];

    final itemRows = await _client
        .from('cart_items')
        .select('id, product_id, quantity, note, unit_price, bundle_id')
        .eq('cart_id', cartId)
        .order('created_at') as List;

    if (itemRows.isEmpty) return const <CartLine>[];

    final itemIds = <String>[
      for (final row in itemRows)
        if (row is Map && (row['id']?.toString() ?? '').isNotEmpty)
          row['id'].toString(),
    ];
    final optionsByItem = await _optionsByCartItem(itemIds);

    final lines = <CartLine>[];
    for (final row in itemRows) {
      if (row is! Map) continue;
      final productId = Db.text(row['product_id']);
      if (productId.isEmpty) continue;
      final itemId = Db.text(row['id']);
      final optionIds = optionsByItem[itemId] ?? const <String>[];
      final bundleId = Db.text(row['bundle_id']).trim();
      lines.add(
        CartLine(
          productId: productId,
          quantity: Db.asInt(row['quantity'], fallback: 1).clamp(1, 99),
          note: Db.text(row['note']),
          optionValueIds: canonicalOptionIds(optionIds),
          unitPrice: Db.asDoubleOrNull(row['unit_price']),
          bundleId: bundleId.isEmpty ? null : bundleId,
        ),
      );
    }
    return lines;
  }

  /// The caller's own active cart for [branch], or null when there is none.
  ///
  /// The read is scoped to the caller by the `carts_select_own` policy, so a
  /// cart belonging to somebody else is invisible here and cannot be selected.
  Future<String?> _activeCartId(String branchId) async {
    final rows = await _client
        .from('carts')
        .select('id')
        .eq('branch_id', branchId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1) as List;
    for (final row in rows) {
      if (row is Map) {
        final id = Db.text(row['id']);
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  /// Option value ids per cart line.
  ///
  /// `public.cart_item_options` is the bridge view for the option rows the
  /// server writes next to every priced line. It is read separately because
  /// PostgREST cannot infer the relationship on a view.
  Future<Map<String, List<String>>> _optionsByCartItem(List<String> itemIds) async {
    if (itemIds.isEmpty) return const {};
    final rows = await _client
        .from('cart_item_options')
        .select('cart_item_id, option_value_id')
        .inFilter('cart_item_id', itemIds) as List;

    final byItem = <String, List<String>>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final itemId = Db.text(row['cart_item_id']);
      final optionId = Db.text(row['option_value_id']);
      if (itemId.isEmpty || optionId.isEmpty) continue;
      byItem.putIfAbsent(itemId, () => <String>[]).add(optionId);
    }
    return byItem;
  }

  @override
  Future<void> saveLines({
    String? branchId,
    required List<CartLine> lines,
  }) async {
    final branch = branchId?.trim() ?? '';
    if (branch.isEmpty || !_signedIn) return;

    final allowed = await RateLimitClient().check('replace_cart');
    if (!allowed) {
      throw StateError('replace_cart rate limit exceeded. Try again later.');
    }

    final payload = <Map<String, dynamic>>[
      for (final line in lines) line.toServerPayload(),
    ];
    final response = await _rpc('replace_cart', <String, dynamic>{
      'p_branch_id': branch,
      'p_lines': payload,
    });
    if (response is! List || response.isEmpty || response.first is! Map) {
      throw StateError('replace_cart returned no cart.');
    }
    final row = Db.asMap(response.first);
    if (Db.text(row['cart_id']).isEmpty) {
      throw StateError('replace_cart returned no cart id.');
    }
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) {
    final override = _rpcOverride;
    return override == null
        ? _client.rpc(name, params: params)
        : override(name, params);
  }
}
