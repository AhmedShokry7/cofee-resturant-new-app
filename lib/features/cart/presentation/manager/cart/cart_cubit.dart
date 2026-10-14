import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

part 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState(items: []));

  static const _storageKey = 'cart_v1';
  static const _maxItems = 50;

  Future<void> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty || isClosed) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final menu = getMenuList();
      final items = <CartItem>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final id = entry['productId']?.toString();
        if (id == null) continue;
        for (final product in menu) {
          if (product.id != id) continue;
          final quantity =
              (entry['quantity'] as num?)?.toInt().clamp(1, 99) ?? 1;
          items.add(
            CartItem(
              product: product,
              quantity: quantity,
              note: entry['note']?.toString() ?? '',
              unitPrice: (entry['unitPrice'] as num?)?.toDouble(),
            ),
          );
        }
        if (items.length >= _maxItems) break;
      }
      emit(CartState(items: items));
    } catch (_) {
      // Best-effort: start with an empty cart rather than crash.
    }
  }

  void add(
    ProductModel product, {
    int quantity = 1,
    String note = '',
    double? unitPrice,
  }) {
    final items = [...state.items];
    final index = items.indexWhere(
      (item) => item.product.id == product.id && item.note == note,
    );
    if (index == -1) {
      items.add(
        CartItem(
          product: product,
          quantity: quantity,
          note: note,
          unitPrice: unitPrice,
        ),
      );
    } else {
      items[index] = items[index].copyWith(
        quantity: items[index].quantity + quantity,
      );
    }
    emit(CartState(items: items));
    _persist();
  }

  void increment(String productId) => _changeQuantity(productId, 1);

  void decrement(String productId) => _changeQuantity(productId, -1);

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

  void clear() {
    emit(const CartState(items: []));
    _persist();
  }

  void _changeQuantity(String productId, int delta) {
    final items = [...state.items];
    final index = items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return;
    final quantity = items[index].quantity + delta;
    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      items[index] = items[index].copyWith(quantity: quantity);
    }
    emit(CartState(items: items));
    _persist();
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
