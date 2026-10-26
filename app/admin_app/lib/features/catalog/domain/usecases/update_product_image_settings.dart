import 'package:flutter/material.dart';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/catalog/product_image_repository.dart';

class UpdateProductImageSettingsUseCase {
  const UpdateProductImageSettingsUseCase(this._repository);

  final ProductImageRepository _repository;

  Future<List<AdminProductImage>> call({
    required AdminProductImage image,
    BoxFit? fit,
    Alignment? alignment,
  }) => _repository.updateProductImageSettings(
    image: image,
    fit: fit,
    alignment: alignment,
  );
}
