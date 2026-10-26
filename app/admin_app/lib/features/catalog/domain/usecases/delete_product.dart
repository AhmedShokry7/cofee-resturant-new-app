import 'package:admin_app/core/catalog/product_repository.dart';

class DeleteProductUseCase {
  const DeleteProductUseCase(this._repository);

  final ProductRepository _repository;

  Future<void> call(String productId) => _repository.deleteProduct(productId);
}
