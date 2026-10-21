import 'package:new_coffee/features/cart/data/model/cart_line.dart';
import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';

/// The offline stand-in for [SupabaseCartRepository].
///
/// It is used when no backend is configured and by widget tests. There is no
/// server cart to read or write in that case, so it answers "there is no
/// server" instead of "the server cart is empty" — the difference matters,
/// because an empty answer would silently clear the customer's cart.
///
/// The device copy of the cart lives in the cubit's own storage, keyed per
/// account, and keeps working without a backend.
class LocalCartRepository implements CartRepository {
  const LocalCartRepository();

  @override
  Future<List<CartLine>?> fetchLines({String? branchId}) async => null;

  @override
  Future<void> saveLines({
    String? branchId,
    required List<CartLine> lines,
  }) async {}
}
