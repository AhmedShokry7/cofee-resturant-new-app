/// The screen an answer asks the customer to open.
///
/// The engine names a destination, never a route string: the route belongs to
/// the page that registers it, and [routeForAssistantDestination] is the one
/// place that maps between the two.
enum AssistantDestination { coupons, orders, checkout }

/// Tool calls the assistant engine can request (LLM-style function calling).
///
/// The engine itself stays pure/testable: it only *describes* actions in
/// [AssistantAnswer.actions], and the UI layer (which owns BuildContext)
/// executes them — e.g. adding products to the real [CartCubit].
class CartAction {
  const CartAction({
    required this.productId,
    this.quantity = 1,
    this.note = '',
    this.optionValueIds = const [],
    this.unitPrice,
    this.remove = false,
  });

  final String productId;
  final int quantity;
  final String note;

  /// Structured option selections behind [note]. The cart uses these rather
  /// than parsing display text back into options.
  final List<String> optionValueIds;

  /// Variant-adjusted unit price (size + extras). Null = base price.
  final double? unitPrice;

  /// True when the action takes the product out of the cart instead of
  /// putting it in.
  final bool remove;

  Map<String, dynamic> toJson() => {
    'type': remove ? 'remove_from_cart' : 'add_to_cart',
    'productId': productId,
    'quantity': quantity,
    if (note.isNotEmpty) 'note': note,
    if (optionValueIds.isNotEmpty) 'optionValueIds': optionValueIds,
    if (unitPrice != null) 'unitPrice': unitPrice,
  };
}
