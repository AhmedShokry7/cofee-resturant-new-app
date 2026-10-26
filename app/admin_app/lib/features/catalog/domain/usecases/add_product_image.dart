import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/catalog/product_image_repository.dart';

class AddProductImageUseCase {
  const AddProductImageUseCase(this._repository);

  final ProductImageRepository _repository;

  Future<List<AdminProductImage>> call({
    required String productId,
    required String imageUrl,
  }) => _repository.addProductImage(productId: productId, imageUrl: imageUrl);
}
