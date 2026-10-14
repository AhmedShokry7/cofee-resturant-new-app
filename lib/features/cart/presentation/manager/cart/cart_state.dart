part of 'cart_cubit.dart';

@immutable
class CartItem {
  const CartItem({
    required this.product,
    this.quantity = 1,
    this.note = '',
    this.unitPrice,
  });

  final ProductModel product;
  final int quantity;

  /// Variant details chosen in chat (e.g. "large, less sugar").
  final String note;

  /// Variant-adjusted unit price (size + extras). Null = base price.
  final double? unitPrice;

  double get effectiveUnit => unitPrice ?? product.price;

  double get total => effectiveUnit * quantity;

  CartItem copyWith({int? quantity, String? note, double? unitPrice}) =>
      CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
        unitPrice: unitPrice ?? this.unitPrice,
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
