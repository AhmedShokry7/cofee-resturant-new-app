part of 'cart_cubit.dart';

/// One device line, as the server stores and prices it.
///
/// A bundle line has no product of its own: it becomes one line per component,
/// each scaled by the quantity ordered, and every line carries the bundle id so
/// the bundle share keeps being charged. A line that reads as a bundle but has
/// no components names no product either, so it is not sent at all.
///
/// This is the only place that rule is written. The cart syncs it, and the
/// checkout prices an order from the same expansion, so the two can never
/// disagree about what a bundle costs.
List<CartLine> serverLinesForItems(List<CartItem> items) => [
  for (final item in items)
    ...serverLinesFor(
      quantity: item.quantity,
      note: item.note,
      optionValueIds: item.optionValueIds,
      bundleId: item.bundleId,
      isBundle: item.isBundle,
      productId: item.product.id,
      components: item.bundleComponents,
    ),
];

/// The server lines for a cart read back from the device storage.
List<CartLine> serverLinesForEntries(List<Map<String, dynamic>> entries) => [
  for (final entry in entries)
    ...serverLinesFor(
      quantity: (entry['quantity'] as num?)?.toInt() ?? 1,
      note: entry['note']?.toString() ?? '',
      optionValueIds: canonicalOptionIds(
        (entry['optionValueIds'] as List?)?.map((e) => e.toString()) ??
            const <String>[],
      ),
      bundleId: entry['bundleId']?.toString(),
      isBundle: entry['isBundle'] == true,
      productId: entry['productId']?.toString(),
      components: bundleComponentsOf(entry),
    ),
];

List<CartLine> serverLinesFor({
  required int quantity,
  required String note,
  required List<String> optionValueIds,
  required String? bundleId,
  required bool isBundle,
  String? productId,
  List<CartBundleComponent> components = const [],
}) {
  if (components.isEmpty) {
    return isBundle
        ? const []
        : [
            CartLine(
              productId: productId ?? '',
              quantity: quantity,
              note: note,
              optionValueIds: optionValueIds,
              bundleId: bundleId,
            ),
          ];
  }
  return [
    for (final component in components)
      CartLine(
        productId: component.productId,
        quantity: component.quantity * quantity,
        note: note,
        optionValueIds: optionValueIds,
        bundleId: bundleId,
      ),
  ];
}

/// The components of a stored bundle line, in the order they were saved.
List<CartBundleComponent> bundleComponentsOf(Map<String, dynamic> entry) {
  final components = <CartBundleComponent>[];
  final rawComponents = entry['bundleComponents'];
  if (rawComponents is List) {
    for (final raw in rawComponents) {
      if (raw is Map) {
        components.add(
          CartBundleComponent.fromJson(Map<String, dynamic>.from(raw)),
        );
      }
    }
  }
  return components;
}

/// True when two lines were built from exactly the same option choices.
bool sameOptionIds(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Combines the server cart with the device copy.
///
/// The server owns the product lines. A bundle is a device-side wrapper around
/// component lines, so it is re-attached to the component lines the server kept,
/// matched by bundle id as well as product/note/options: a standalone line of
/// the same product must never be pulled into a bundle.
/// A bundle the server does not know any more is dropped, because the server is
/// the authority. Component lines the device has no bundle for stay ordinary
/// lines but keep their `bundleId`, so the next write still sends the bundle
/// identity instead of inventing a standalone price.
List<Map<String, dynamic>> mergeServerLines(
  List<CartLine> serverLines,
  List<Map<String, dynamic>> cachedEntries,
) {
  final remaining = List<CartLine>.of(serverLines);
  final merged = <Map<String, dynamic>>[];

  for (final entry in cachedEntries) {
    if (entry['isBundle'] != true) continue;
    final components = bundleComponentsOf(entry);
    if (components.isEmpty) continue;

    final bundleId =
        entry['bundleId']?.toString() ?? entry['productId']?.toString() ?? '';
    if (bundleId.isEmpty) continue;

    final note = entry['note']?.toString() ?? '';
    final optionIds = canonicalOptionIds(
      (entry['optionValueIds'] as List?)?.map((e) => e.toString()) ??
          const <String>[],
    );
    final matched = <CartLine>[];
    var complete = true;
    for (final component in components) {
      final index = remaining.indexWhere(
        (line) =>
            line.productId == component.productId &&
            line.bundleId == bundleId &&
            line.note == note &&
            sameOptionIds(line.optionValueIds, optionIds),
      );
      if (index == -1) {
        complete = false;
        break;
      }
      matched.add(remaining.removeAt(index));
    }
    if (!complete) {
      // The bundle is not on the server any more: put the lines that were taken
      // back and let the server decide.
      remaining.insertAll(0, matched);
      continue;
    }

    var quantity = 1 << 30;
    for (var i = 0; i < matched.length; i++) {
      final perBundle = components[i].quantity;
      final held = perBundle <= 0
          ? matched[i].quantity
          : matched[i].quantity ~/ perBundle;
      if (held < quantity) quantity = held;
    }
    if (quantity < 1) {
      // Never turn "not enough components" into a bundle by clamping.
      remaining.insertAll(0, matched);
      continue;
    }
    // The server priced every component line, including its share of the bundle,
    // so the wrapper's price is the sum of those shares. The device copy keeps
    // the price it was bought at: leaving it in the merged line meant a branch
    // change or a bundle re-price never reached the cart total.
    double? serverBundlePrice;
    for (var i = 0; i < matched.length; i++) {
      final unit = matched[i].unitPrice;
      final perBundle = components[i].quantity;
      if (unit == null || perBundle <= 0) {
        serverBundlePrice = null;
        break;
      }
      serverBundlePrice = (serverBundlePrice ?? 0) + unit * perBundle;
    }

    merged.add({
      ...entry,
      'quantity': quantity.clamp(1, CartLimits.maxQuantity),
      if (serverBundlePrice != null) ...{
        'bundlePrice': serverBundlePrice,
        'unitPrice': serverBundlePrice,
      },
    });
  }

  for (final line in remaining) {
    merged.add({
      'productId': line.productId,
      'quantity': line.quantity,
      if (line.note.isNotEmpty) 'note': line.note,
      if (line.optionValueIds.isNotEmpty) 'optionValueIds': line.optionValueIds,
      if (line.unitPrice != null) 'unitPrice': line.unitPrice,
      if (line.bundleId != null && line.bundleId!.trim().isNotEmpty)
        'bundleId': line.bundleId,
    });
  }
  return merged;
}

/// The stored cart, or nothing when the payload is not a list.
List<Map<String, dynamic>> decodeCartEntries(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return [
    for (final entry in decoded)
      if (entry is Map) Map<String, dynamic>.from(entry),
  ];
}
