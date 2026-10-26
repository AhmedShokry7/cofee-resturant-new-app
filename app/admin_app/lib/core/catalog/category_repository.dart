import 'dart:typed_data';

import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product_image.dart';

/// التصنيفات وصورها.
abstract interface class CategoryRepository {
  Future<AdminCategory> createCategory({
    required String nameAr,
    required String nameEn,
    String? descriptionAr,
    String? descriptionEn,
  });

  Future<AdminCategory> updateCategory({
    required String categoryId,
    required String nameAr,
    required String nameEn,
    String? descriptionAr,
    String? descriptionEn,
  });

  Future<void> deleteCategory(String categoryId);

  Future<void> setCategoryActive(String categoryId, bool isActive);

  Future<void> updateCategoryImage(String categoryId, String? imageUrl);

  Future<String> uploadCategoryImage({
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  });

  Future<void> deleteCategoryImageFile(String? imageUrl);
}
