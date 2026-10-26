import 'package:flutter/material.dart';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/catalog/product_image_repository.dart';

class ApplyProductImageSettingsUseCase {
  const ApplyProductImageSettingsUseCase(this._repository);

  final ProductImageRepository _repository;

  Future<List<AdminProductImage>> call({
    required String productId,
    BoxFit? fit,
    Alignment? alignment,
  }) => _repository.applyProductImageSettings(
    productId: productId,
    fit: fit,
    alignment: alignment,
  );
}
