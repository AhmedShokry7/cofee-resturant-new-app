import 'package:admin_app/core/catalog/product_repository.dart';

class SetFeaturedUseCase {
  const SetFeaturedUseCase(this._repository);

  final ProductRepository _repository;

  Future<void> call(String productId, bool isFeatured) =>
      _repository.setFeatured(productId, isFeatured);
}
