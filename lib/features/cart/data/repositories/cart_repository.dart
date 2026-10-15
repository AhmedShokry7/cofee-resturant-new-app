/// Contract for cart persistence.
///
/// Screens and cubits depend only on this interface, so the data source can be
/// swapped without touching widget code. Two implementations ship:
/// [SupabaseCartRepository] when Supabase is configured, and
/// [LocalCartRepository] as the offline fallback.
abstract class CartRepository {
  /// Add a product (or bundle component) to the cart.
  ///
  /// [unitPrice] is the price per single item. When [bundleId] is supplied the
  /// server computes the component's proportional share of the bundle price;
  /// otherwise the shelf price from [CatalogRepository.resolvePrice] applies.
  Future<void> addItem({
    required String productId,
    required int quantity,
    required String note,
    required List<String> optionValueIds,
    required double unitPrice,
    String? bundleId,
  });

  /// Remove a cart line by its stable [lineId].
  Future<void> removeItem(String lineId);

  /// Rebuild the cart from the server. When Supabase is unavailable this
  /// returns an empty cart; callers should then fall back to local state.
  Future getCartSummary();

  /// Clear the cart on the server (when configured) and reset local state.
  Future<void> clearCart();
}