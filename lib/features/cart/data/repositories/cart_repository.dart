import 'package:new_coffee/features/cart/data/model/cart_line.dart';

/// How much one cart may hold.
///
/// These are server rules, not UI choices: `orders.add_to_cart` and the atomic
/// checkout both reject a quantity above 99 (`supabase/migrations/058`), and a
/// device slot that kept more lines than it could store used to show lines that
/// vanished on the next restart. The cubit, the mapper and the reader all read
/// the numbers here so no copy can drift.
abstract final class CartLimits {
  static const int maxQuantity = 99;
  static const int maxLines = 50;
}

/// Contract for the server-side cart.
///
/// Screens and cubits depend only on this interface, so the data source can be
/// swapped without touching widget code. [SupabaseCartRepository] is the
/// production implementation; [LocalCartRepository] is the offline stand-in
/// used when no backend is configured and by widget tests.
///
/// The server owns the cart of a signed-in customer: it is written on every
/// change and read back on every load, so the same account sees the same
/// cart on every device. Ownership is resolved on the server through
/// `auth.uid()`; the client never supplies a user id, so one customer can
/// never read or write another customer's cart.
abstract class CartRepository {
  /// The caller's own cart at [branchId].
  ///
  /// Returns null when there is no server to ask: no session, no branch, or no
  /// backend at all. The caller then keeps whatever it has on the device
  /// instead of treating the absence of a server as an empty cart.
  Future<List<CartLine>?> fetchLines({String? branchId});

  /// Replaces the caller's own cart at [branchId] with [lines].
  ///
  /// The write is atomic: the server either stores the whole cart or keeps
  /// the previous one. A failure is reported, never swallowed, so the caller
  /// can tell the customer that the change did not reach the server.
  Future<void> saveLines({String? branchId, required List<CartLine> lines});
}
