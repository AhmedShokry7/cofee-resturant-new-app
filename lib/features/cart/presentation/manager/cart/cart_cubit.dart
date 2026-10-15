import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

part 'cart_state.dart';

/// Owns the customer-facing cart.
///
/// The active cart stays on the device because ordering needs a signed-in
/// customer, a selected branch and a completed checkout/payment flow. The
/// server intentionally rejects client-supplied prices, and bundle discounts
/// have no server-side line representation yet, so prematurely moving local
/// writes to `upsert_cart_item()` would charge full shelf price for bundle
/// components. What moved to the repository here is product resolution:
/// stored lines are rebuilt from the current catalogue instead of from the
/// compiled menu, and the chosen option ids travel with the line instead of
/// being flattened away.
class CartCubit extends Cubit<CartState> {
  CartCubit({
    required CatalogRepository repository,
    this.branchId,
  })  : _repository = repository,
        super(const CartState(items: [])) {
    load();
  }

  final CatalogRepository _repository;

  /// Branch whose catalogue rows apply to restored lines.
  String? branchId;

  static const _storageKey = 'cart_v1';
  static const _maxItems = 50;

  /// Restored rows stay within the catalogue's configured page width.
  static const _catalogPageSize = 200;

  Future<void> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty || isClosed) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final products = await _repository.getProducts(
        branchId: branchId,
        limit: _catalogPageSize,
      );
      final productsById = {for (final p in products) p.id: p};
      final items = <CartItem>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final id = entry['productId']?.toString();
        if (id == null || id.isEmpty) continue;
        final product =
            productsById[id] ?? await _repository.getById(id, branchId: branchId);
        // A product that no longer exists is dropped. Showing its old id with
        // no name, price or image would be worse than an honestly shorter cart.
        if (product == null) continue;

        final quantity =
            (entry['quantity'] as num?)?.toInt().clamp(1, 99) ?? 1;
        items.add(
          CartItem(
            product: product,
            quantity: quantity,
            note: entry['note']?.toString() ?? '',
            optionValueIds: _optionIds(entry['optionValueIds']),
            unitPrice: (entry['unitPrice'] as num?)?.toDouble(),
          ),
        );
        if (items.length >= _maxItems) break;
      }
      if (isClosed) return;
      emit(CartState(items: items));
    } catch (_) {
      // Best-effort: start with an empty cart rather than crash.
    }
  }

  Future<void> setBranch(String? branchId) {
    if (branchId == this.branchId) return Future.value();
    this.branchId = branchId;
    return load();
  }

  void add(
    ProductModel product, {
    int quantity = 1,
    String note = '',
    List<String> optionValueIds = const [],
    double? unitPrice,
  }) {
    final items = [...state.items];
    final optionIds = [
      for (final id in optionValueIds)
        if (id.trim().isNotEmpty) id,
    ]..sort();
    final index = items.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.note == note &&
          _sameOptions(item.optionValueIds, optionIds),
    );
    if (index == -1) {
      items.add(
        CartItem(
          product: product,
          quantity: quantity.clamp(1, 99),
          note: note,
          optionValueIds: optionIds,
          unitPrice: unitPrice,
        ),
      );
    } else {
      items[index] = items[index].copyWith(
        quantity: (items[index].quantity + quantity).clamp(1, 99),
      );
    }
    emit(CartState(items: items));
    _persist();
  }

  /// Kept for callers that only know a product. The cart page and stepper now
  /// use the line-specific variants below, so different notes/options for the
  /// same product are no longer conflated.
  void increment(String productId) => _changeQuantityForProduct(productId, 1);

  void decrement(String productId) => _changeQuantityForProduct(productId, -1);

  void remove(String productId) {
    emit(
      CartState(
        items: state.items
            .where((item) => item.product.id != productId)
            .toList(),
      ),
    );
    _persist();
  }

  void incrementLine(String lineId) => _changeQuantity(lineId, 1);

  void decrementLine(String lineId) => _changeQuantity(lineId, -1);

  void removeLine(String lineId) {
    emit(
      CartState(
        items: state.items.where((item) => item.lineId != lineId).toList(),
      ),
    );
    _persist();
  }

  void clear() {
    emit(const CartState(items: []));
    _persist();
  }

  void _changeQuantityForProduct(String productId, int delta) {
    final items = [...state.items];
    final index = items.indexWhere((item) => item.product.id == productId);
    _applyQuantity(items, index, delta);
  }

  void _changeQuantity(String lineId, int delta) {
    final items = [...state.items];
    final index = items.indexWhere((item) => item.lineId == lineId);
    _applyQuantity(items, index, delta);
  }

  void _applyQuantity(List<CartItem> items, int index, int delta) {
    if (index == -1) return;
    final quantity = (items[index].quantity + delta).clamp(0, 99);
    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      items[index] = items[index].copyWith(quantity: quantity);
    }
    emit(CartState(items: items));
    _persist();
  }

  static bool _sameOptions(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<String> _optionIds(dynamic raw) {
    if (raw is List) {
      final ids = <String>[
        for (final value in raw)
          if (value?.toString().trim().isNotEmpty ?? false)
            value.toString(),
      ]..sort();
      return ids;
    }
    return const [];
  }

  Future<void> _persist() async {
    try {
      await SharedPref.setValue(
        key: _storageKey,
        value: jsonEncode(
          state.items
              .take(_maxItems)
              .map(
                (item) => {
                  'productId': item.product.id,
                  'quantity': item.quantity,
                  if (item.note.isNotEmpty) 'note': item.note,
                  if (item.optionValueIds.isNotEmpty)
                    'optionValueIds': item.optionValueIds,
                  if (item.unitPrice != null) 'unitPrice': item.unitPrice,
                },
              )
              .toList(),
        ),
      );
    } catch (_) {
      // Best-effort: never break the cart if storage fails.
    }
  }
}
