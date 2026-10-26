import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:admin_app/core/models/admin_product_image.dart';

/// صور المنتج: قراءتها وترتيبها وإعدادات عرضها وملفاتها في المخزن.
abstract interface class ProductImageRepository {
  Future<List<AdminProductImage>> loadProductImages(
    String productId, {
    String? fallbackImageUrl,
  });

  Future<List<AdminProductImage>> addProductImage({
    required String productId,
    required String imageUrl,
  });

  Future<List<AdminProductImage>> updateProductImage({
    required AdminProductImage image,
    required String imageUrl,
    BoxFit? fit,
    Alignment? alignment,
  });

  Future<List<AdminProductImage>> updateProductImageSettings({
    required AdminProductImage image,
    BoxFit? fit,
    Alignment? alignment,
  });

  Future<List<AdminProductImage>> applyProductImageSettings({
    required String productId,
    BoxFit? fit,
    Alignment? alignment,
  });

  Future<List<AdminProductImage>> deleteProductImage(AdminProductImage image);

  Future<List<AdminProductImage>> setPrimaryProductImage(
    AdminProductImage image,
  );

  Future<List<AdminProductImage>> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  });

  Future<List<AdminProductImage>> replaceProductImageWithFile({
    required AdminProductImage image,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    BoxFit? fit,
    Alignment? alignment,
    void Function(AdminImageUploadPhase phase)? onPhase,
  });
}
