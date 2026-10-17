import 'dart:convert';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';

/// Device persistence for one customer's cart. Used by widget tests and as
/// the offline store behind [CartCubit]; production server mirroring lives in
/// [SupabaseCartRepository].
///
/// The line identity matches the server (see `orders.cart_items.options_key`):
/// a line is the tuple (product, note, sorted option value ids). Two adds merge
/// only when all three are equal, so two configurations of the same product
/// stay separate and a repeated add of the same configuration adds quantity.
class LocalCartRepository implements CartRepository {
  LocalCartRepository();

  static const _storageKey = 'cart_v1_local';

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
    final raw = await SharedPref.getValue(key: _storageKey);
    final items = raw != null && raw.isNotEmpty
        ? (jsonDecode(raw) as List<dynamic>).toList()
        : <dynamic>[];
    final options = canonicalOptionIds(optionValueIds);
    final key = optionsKey(optionValueIds);

    final index = items.indexWhere(
      (item) =>
          item is Map &&
          item['productId'] == productId &&
          _noteOf(item) == note &&
          optionsKey(_optionIdsOf(item)) == key,
    );

    if (index == -1) {
      items.add({
        'productId': productId,
        'quantity': quantity.clamp(1, 99),
        'note': note,
        'optionValueIds': options,
        'unitPrice': unitPrice,
        if (bundleId != null && bundleId.trim().isNotEmpty)
          'bundleId': bundleId.trim(),
      });
    } else {
      final current = (items[index]['quantity'] as num?)?.toInt() ?? 0;
      items[index]['quantity'] = (current + quantity).clamp(1, 99);
      // A re-add refreshes the price and bundle membership, matching the
      // server's ON CONFLICT update.
      items[index]['unitPrice'] = unitPrice;
      final normalizedBundle = bundleId?.trim() ?? '';
      if (normalizedBundle.isEmpty) {
        items[index].remove('bundleId');
      } else {
        items[index]['bundleId'] = normalizedBundle;
      }
    }
    await SharedPref.setValue(key: _storageKey, value: jsonEncode(items));
  }

  @override
  Future<void> clearCart({String? branchId}) async {
    await SharedPref.setValue(key: _storageKey, value: jsonEncode([]));
  }

  /// Sorted, de-duplicated, non-empty option value ids. This is the canonical
  /// order that the identity key is built from, so the client never depends on
  /// the order the UI happened to collect the selections in.
  static List<String> canonicalOptionIds(Iterable<String> ids) {
    final set = <String>{
      for (final id in ids)
        if (id.trim().isNotEmpty) id,
    };
    return set.toList()..sort();
  }

  /// Canonical identity for a set of option selections: sorted and joined.
  static String optionsKey(Iterable<String> ids) =>
      canonicalOptionIds(ids).join(',');

  static String _noteOf(Map<dynamic, dynamic> item) =>
      item['note']?.toString() ?? '';

  static List<String> _optionIdsOf(Map<dynamic, dynamic> item) {
    final raw = item['optionValueIds'];
    if (raw is List) {
      return [for (final value in raw) value.toString()];
    }
    return const [];
  }
}
