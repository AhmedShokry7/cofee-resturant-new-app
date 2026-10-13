import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/menu/data/model/product_model.dart';

part 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState(items: []));

  void add(ProductModel product) {
    final items = [...state.items];
    final index = items.indexWhere((item) => item.product.id == product.id);
    if (index == -1) {
      items.add(CartItem(product: product));
    } else {
      items[index] = items[index].copyWith(
        quantity: items[index].quantity + 1,
      );
    }
    emit(CartState(items: items));
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
  }

  void clear() => emit(const CartState(items: []));

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
  }
}
