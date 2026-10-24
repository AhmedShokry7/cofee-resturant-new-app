import 'package:flutter/foundation.dart';

/// One cart line as the server stores it.
///
/// The line identity is the tuple (product, note, sorted option value ids,
/// bundle), which is exactly what `orders.cart_items` uses through its
/// `unique (cart_id, product_id, note, options_key, bundle_key)` constraint.
/// Two configurations of the same product are therefore two lines, and a
/// repeated add of the same configuration is one line with a bigger quantity.
/// The bundle is part of the identity so a bundle component never merges with
/// a standalone product of the same configuration.
///
/// A line carries no client price on the way out: the server prices every line
/// from the catalogue. [unitPrice] is only filled when reading a line the
/// server already priced.
@immutable
class CartLine {
  const CartLine({
    required this.productId,
    required this.quantity,
    this.note = '',
    this.optionValueIds = const [],
    this.unitPrice,
    this.bundleId,
  });

  final String productId;
  final int quantity;
  final String note;

  /// Option value ids behind this line, sorted and de-duplicated.
  final List<String> optionValueIds;

  /// The price the server computed for this line. Null when the line has not
  /// been priced by the server yet.
  final double? unitPrice;

  /// Set when the line is one component of a bundle, so the server keeps
  /// charging that component's share of the bundle price.
  final String? bundleId;

  /// Canonical identity of this line, independent of the order the option
  /// values were collected in.
  String get identity =>
      '$productId::$note::${optionValueIds.join(',')}::${bundleId ?? ''}';

  /// The payload the server expects. It never carries a price: `replace_cart`
  /// re-prices every line from the catalogue.
  Map<String, dynamic> toServerPayload() => <String, dynamic>{
        'product_id': productId,
        'quantity': quantity,
        'note': note,
        'option_value_ids': optionValueIds,
        if (bundleId != null && bundleId!.trim().isNotEmpty)
          'bundle_id': bundleId!.trim(),
      };

  @override
  bool operator ==(Object other) =>
      other is CartLine &&
      other.productId == productId &&
      other.quantity == quantity &&
      other.note == note &&
      other.bundleId == bundleId &&
      other.unitPrice == unitPrice &&
      _sameIds(other.optionValueIds, optionValueIds);

  @override
  int get hashCode => Object.hash(
        productId,
        quantity,
        note,
        bundleId,
        unitPrice,
        Object.hashAll(optionValueIds),
      );

  @override
  String toString() =>
      'CartLine($productId x$quantity, note: "$note", options: $optionValueIds'
      '${bundleId == null ? '' : ', bundle: $bundleId'})';
}

/// Sorted, de-duplicated, non-empty option value ids.
///
/// This is the canonical order the line identity is built from, so the client
/// never depends on the order the UI happened to collect the selections in.
List<String> canonicalOptionIds(Iterable<String> ids) {
  final set = <String>{
    for (final id in ids)
      if (id.trim().isNotEmpty) id,
  };
  return set.toList()..sort();
}

bool _sameIds(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
