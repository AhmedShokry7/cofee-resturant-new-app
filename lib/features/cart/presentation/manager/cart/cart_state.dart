part of 'cart_cubit.dart';

@immutable
class CartBundleComponent {
  const CartBundleComponent({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final int quantity;
  final double unitPrice;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory CartBundleComponent.fromJson(Map<String, dynamic> json) =>
      CartBundleComponent(
        productId: json['productId']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      );
}

@immutable
class CartItem {
  const CartItem({
    required this.product,
    this.quantity = 1,
    this.note = '',
    this.optionValueIds = const [],
    this.unitPrice,
    this.bundleId,
    this.bundleComponents = const [],
  });

  final ProductModel product;
  final int quantity;

  /// Variant details chosen in chat (e.g. "large, less sugar").
  final String note;

  /// Structured option value ids behind [note].
  final List<String> optionValueIds;

  /// Variant-adjusted unit price (size + extras). Null = base price.
  final double? unitPrice;

  /// Bundle this line belongs to, when it was added as a bundle component.
  final String? bundleId;

  /// Components of a bundle sold as one cart line. Empty for standalone
  /// products and for legacy bundle-component lines.
  final List<CartBundleComponent> bundleComponents;

  bool get isBundle => bundleComponents.isNotEmpty;

  /// Stable merge identity for one product/note/option combination.
  String get lineId {
    final prefix = isBundle ? 'bundle:${bundleId ?? product.id}' : product.id;
    return '$prefix::$note::${optionValueIds.join(',')}';
  }

  double get effectiveUnit => unitPrice ?? product.price;

  double get total => effectiveUnit * quantity;

  CartItem copyWith({
    int? quantity,
    String? note,
    List<String>? optionValueIds,
    double? unitPrice,
    String? bundleId,
    List<CartBundleComponent>? bundleComponents,
  }) =>
      CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
        optionValueIds: optionValueIds ?? this.optionValueIds,
        unitPrice: unitPrice ?? this.unitPrice,
        bundleId: bundleId ?? this.bundleId,
        bundleComponents: bundleComponents ?? this.bundleComponents,
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