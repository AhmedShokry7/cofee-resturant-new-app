part of 'cart_cubit.dart';

@immutable
class CartItem {
  const CartItem({
    required this.product,
    this.quantity = 1,
    this.note = '',
    this.optionValueIds = const [],
    this.unitPrice,
    this.bundleId,
  });

  final ProductModel product;
  final int quantity;

  /// Variant details chosen in chat (e.g. "large, less sugar").
  final String note;

  /// Structured option value ids behind [note].
  ///
  /// The server re-prices from option identity, not from display text or from
  /// a client-supplied amount, so the selected ids must travel with the line.
  final List<String> optionValueIds;

  /// Variant-adjusted unit price (size + extras). Null = base price.
  final double? unitPrice;

  /// Bundle this line belongs to, when it was added as a bundle component.
  ///
  /// The server prices a bundle component as its proportional share of the
  /// bundle price, so the id must survive in the cart and be replayed at
  /// checkout; dropping it would silently re-price the component at shelf price.
  final String? bundleId;

  /// Stable merge identity for one product/note/option combination.
  ///
  /// Deliberately excludes [bundleId]: the server line identity is
  /// (cart, product, note, options), and a re-add updates the line price, so
  /// two adds that differ only by bundle must merge on both sides.
  String get lineId =>
      '${product.id}::$note::${optionValueIds.join(',')}';

  double get effectiveUnit => unitPrice ?? product.price;

  double get total => effectiveUnit * quantity;

  CartItem copyWith({
    int? quantity,
    String? note,
    List<String>? optionValueIds,
    double? unitPrice,
    String? bundleId,
  }) =>
      CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
        optionValueIds: optionValueIds ?? this.optionValueIds,
        unitPrice: unitPrice ?? this.unitPrice,
        bundleId: bundleId ?? this.bundleId,
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
