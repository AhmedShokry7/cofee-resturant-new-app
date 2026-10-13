part of 'cart_cubit.dart';

@immutable
class CartItem {
  const CartItem({required this.product, this.quantity = 1});

  final ProductModel product;
  final int quantity;

  double get total => product.price * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
      );
}

@immutable
class CartState {
  const CartState({required this.items});

  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;

  int get count => items.fold(0, (sum, item) => sum + item.quantity);

  double get total => items.fold(0, (sum, item) => sum + item.total);
}
