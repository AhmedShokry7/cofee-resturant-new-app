import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/catalog/product_image_repository.dart';

class ReplaceProductImageWithFileUseCase {
  const ReplaceProductImageWithFileUseCase(this._repository);

  final ProductImageRepository _repository;

  Future<List<AdminProductImage>> call({
    required AdminProductImage image,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    BoxFit? fit,
    Alignment? alignment,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) => _repository.replaceProductImageWithFile(
    image: image,
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
    fit: fit,
    alignment: alignment,
    onPhase: onPhase,
  );
}
