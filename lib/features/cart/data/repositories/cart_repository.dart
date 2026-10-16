/// Contract for cart persistence.
///
/// Screens and cubits depend only on this interface, so the data source can be
/// swapped without touching widget code. [SupabaseCartRepository] is the
/// production implementation; [LocalCartRepository] persists the customer's
/// own cart on the device and is used by widget tests.
///
/// The device cart is the checkout source of truth. The server calls below
/// mirror it into the customer's per-branch server cart (resolved by
/// `auth.uid()`, never by a client-supplied id); they are best-effort and
/// must never block or break the local flow.
abstract class CartRepository {
  /// Add a product (or bundle component) to the cart.
  ///
  /// [unitPrice] is the price per single item. When [bundleId] is supplied the
  /// server computes the component's proportional share of the bundle price;
  /// otherwise the shelf price from [CatalogRepository.resolvePrice] applies.
  /// [branchId] selects the server cart; without it (or without a session)
  /// the write stays local-only.
  Future<void> addItem({
    required String productId,
    required int quantity,
    required String note,
    required List<String> optionValueIds,
    required double unitPrice,
    String? bundleId,
    String? branchId,
  });

  /// Clear the cart on the server (when a session and branch select a cart)
  /// and reset local state. Local clearing always happens in the cubit first,
  /// so a mirror failure can never trap items on screen.
  Future<void> clearCart({String? branchId});
}
