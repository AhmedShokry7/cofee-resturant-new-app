import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/catalog/product_image_repository.dart';

class SetPrimaryProductImageUseCase {
  const SetPrimaryProductImageUseCase(this._repository);

  final ProductImageRepository _repository;

  Future<List<AdminProductImage>> call(AdminProductImage image) =>
      _repository.setPrimaryProductImage(image);
}
