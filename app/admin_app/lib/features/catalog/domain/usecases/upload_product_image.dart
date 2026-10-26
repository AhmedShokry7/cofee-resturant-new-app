import 'dart:typed_data';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/catalog/product_image_repository.dart';

class UploadProductImageUseCase {
  const UploadProductImageUseCase(this._repository);

  final ProductImageRepository _repository;

  Future<List<AdminProductImage>> call({
    required String productId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) => _repository.uploadProductImage(
    productId: productId,
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
    onPhase: onPhase,
  );
}
