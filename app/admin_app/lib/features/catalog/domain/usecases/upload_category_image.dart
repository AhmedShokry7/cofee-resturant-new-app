import 'dart:typed_data';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/catalog/category_repository.dart';

class UploadCategoryImageUseCase {
  const UploadCategoryImageUseCase(this._repository);

  final CategoryRepository _repository;

  Future<String> call({
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) => _repository.uploadCategoryImage(
    categoryId: categoryId,
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
    onPhase: onPhase,
  );
}
