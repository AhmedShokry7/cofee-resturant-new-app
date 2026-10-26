import 'package:flutter/material.dart';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/catalog/product_image_repository.dart';

class UpdateProductImageUseCase {
  const UpdateProductImageUseCase(this._repository);

  final ProductImageRepository _repository;

  Future<List<AdminProductImage>> call({
    required AdminProductImage image,
    required String imageUrl,
    BoxFit? fit,
    Alignment? alignment,
  }) => _repository.updateProductImage(
    image: image,
    imageUrl: imageUrl,
    fit: fit,
    alignment: alignment,
  );
}
