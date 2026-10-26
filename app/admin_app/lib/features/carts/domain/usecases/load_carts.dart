import 'package:admin_app/features/carts/data/models/admin_cart.dart';
import 'package:admin_app/features/carts/domain/repositories/cart_repository.dart';

/// قراءة كل السلات المتروكة.
class LoadCartsUseCase {
  const LoadCartsUseCase(this._repository);

  final CartRepository _repository;

  Future<List<AdminCart>> call() => _repository.loadCarts();
}
