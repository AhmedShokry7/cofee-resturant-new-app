import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';
import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/catalog/branch_pricing_repository.dart';
import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/catalog/catalog_repository.dart';
import 'package:admin_app/core/catalog/category_repository.dart';
import 'package:admin_app/core/catalog/product_image_repository.dart';
import 'package:admin_app/core/catalog/product_repository.dart';

/// Reads and writes the products of the admin dashboard.
///
/// The writes go through the `public.admin_*` functions of the database: the
/// PostgREST API only exposes the `public` schema, so the catalogue tables
/// are reached through functions that check the permissions of the caller.
class AdminProductRepository
    implements
        CatalogData,
        CatalogRepository,
        ProductRepository,
        CategoryRepository,
        ProductImageRepository,
        BranchPricingRepository {
  AdminProductRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  /// The columns of a picture of a product.
  static const String _productImageColumns =
      'id,product_id,image_url,alt_ar,alt_en,sort_order,is_primary,fit,alignment';

  /// The columns of a picture of a product, without the display settings.
  static const String _productImageColumnsWithoutSettings =
      'id,product_id,image_url,alt_ar,alt_en,sort_order,is_primary';

  /// The bucket that holds the pictures of the products.
  static const String productImagesBucket = 'product-images';

  /// The formats the bucket accepts.
  static const List<String> productImageTypes = <String>[
    'image/jpeg',
    'image/png',
    'image/webp',
  ];

  /// The biggest picture the bucket accepts.
  static const int maxProductImageBytes = 5 * 1024 * 1024;

  /// Reads one page of the catalogue.
  ///
  /// The page is cut out of the database, so the dashboard never asks for
  /// the whole catalogue at once.
  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) async {
    final term = search?.trim();
    final response = await _supabase.rpc(
      'admin_catalog_snapshot',
      params: {
        'p_branch_id': ?branchId,
        'p_limit': ?limit,
        'p_offset': offset,
        'p_search': ?(term != null && term.isNotEmpty ? term : null),
      },
    );

    final payload = _asMap(response);
    final productRows = _asList(payload['products']);
    final categoryRows = _asList(payload['categories']);

    return AdminCatalogSnapshot(
      products: productRows
          .map((row) => AdminProduct.fromRow(row))
          .toList(growable: false),
      categories: categoryRows
          .map((row) => AdminCategory.fromRow(row))
          .toList(growable: false),
      branchId: payload['branch_id'] as String?,
      total: (payload['total'] as num?)?.toInt() ?? productRows.length,
    );
  }

  /// Creates the product when it has no id yet, updates it otherwise.
  ///
  /// The card has no stock field, so the stock of the branch is left alone:
  /// the database keeps the quantity it already holds.
  @override
  Future<AdminProduct> saveProduct(
    AdminProduct product, {
    String? branchId,
  }) async {
    final response = await _supabase.rpc(
      'admin_save_product',
      params: {
        'p_product_id': product.isDraft ? null : product.id,
        'p_name_ar': product.nameAr,
        'p_name_en': product.nameEn,
        'p_description_ar': product.descriptionAr,
        'p_description_en': product.descriptionEn,
        'p_sku': product.sku.isEmpty ? null : product.sku,
        'p_slug': product.slug.isEmpty ? null : product.slug,
        'p_base_price': product.basePrice,
        'p_compare_at_price': product.compareAtPrice,
        'p_category_id': product.categoryId,
        'p_image_url': product.imageUrl,
        'p_is_featured': product.isFeatured,
        'p_is_active': product.isActive,
        'p_prep_minutes': product.prepMinutes,
        'p_discount_percentage': product.discountPercentage,
        'p_discount_starts_at': product.discountStartsAt?.toIso8601String(),
        'p_discount_ends_at': product.discountEndsAt?.toIso8601String(),
        'p_calories': product.calories,
        'p_allergens': product.allergens,
        'p_branch_id': branchId,
      },
    );

    final row = _asMap(response);
    if (row.isEmpty) {
      throw AdminProductException(S.productNotSaved);
    }
    return AdminProduct.fromRow(row);
  }

  @override
  Future<void> deleteProduct(String productId) async {
    await _supabase.rpc(
      'admin_delete_product',
      params: {'p_product_id': productId},
    );
  }

  /// Creates a category of its own for the dashboard.
  @override
  Future<AdminCategory> createCategory({
    required String nameAr,
    required String nameEn,
    String? descriptionAr,
    String? descriptionEn,
  }) async {
    final response = await _supabase.rpc(
      'admin_create_category',
      params: {
        'p_name_ar': nameAr,
        'p_name_en': nameEn,
        'p_description_ar': descriptionAr,
        'p_description_en': descriptionEn,
      },
    );

    final row = _asMap(response);
    if (row.isEmpty) {
      throw AdminProductException(S.categoryNotCreated);
    }
    return AdminCategory.fromRow(row);
  }

  @override
  Future<AdminCategory> updateCategory({
    required String categoryId,
    required String nameAr,
    required String nameEn,
    String? descriptionAr,
    String? descriptionEn,
  }) async {
    final response = await _supabase.rpc(
      'admin_update_category',
      params: {
        'p_category_id': categoryId,
        'p_name_ar': nameAr,
        'p_name_en': nameEn,
        'p_description_ar': descriptionAr,
        'p_description_en': descriptionEn,
      },
    );

    final row = _asMap(response);
    if (row.isEmpty) {
      throw AdminProductException(S.categoryNotUpdated);
    }
    return AdminCategory.fromRow(row);
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    try {
      await _supabase.rpc(
        'admin_delete_category',
        params: {'p_category_id': categoryId},
      );
    } on PostgrestException catch (error) {
      throw AdminProductException(_categoryDeleteMessage(error));
    }
  }

  String _categoryDeleteMessage(PostgrestException error) {
    if (error.message.contains('category_in_use')) {
      return S.categoryDeleteBlockedByProducts;
    }
    if (error.message.contains('category_not_found')) {
      return S.categoryNotFound;
    }
    return error.message;
  }

  @override
  Future<void> setCategoryActive(String categoryId, bool isActive) async {
    await _supabase.rpc(
      'admin_set_category_active',
      params: {'p_category_id': categoryId, 'p_is_active': isActive},
    );
  }

  @override
  Future<void> updateCategoryImage(String categoryId, String? imageUrl) async {
    await _supabase
        .from('categories')
        .update({'image_url': imageUrl})
        .eq('id', categoryId);
  }

  /// Uploads a picture of a category to the bucket and saves its url.
  @override
  Future<String> uploadCategoryImage({
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    _checkImage(bytes, contentType);
    final path = _categoryImagePath(categoryId, fileName);

    onPhase?.call(AdminImageUploadPhase.uploading);
    await _supabase.storage
        .from(productImagesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final url = _publicImageUrl(path);

    onPhase?.call(AdminImageUploadPhase.saving);
    try {
      await updateCategoryImage(categoryId, url);
    } catch (error) {
      await _removeFile(path);
      rethrow;
    }
    return url;
  }

  /// Removes the picture of a category from the bucket.
  @override
  Future<void> deleteCategoryImageFile(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return;
    final path = _pathOf(imageUrl);
    if (path == null) return;
    await _removeFile(path);
  }

  String _categoryImagePath(String categoryId, String fileName) {
    final extension = _extensionOf(fileName);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(1 << 32).toRadixString(16);
    return 'products/category-$categoryId/${stamp}_$random$extension';
  }

  @override
  Future<void> setFeatured(String productId, bool isFeatured) async {
    await _supabase.rpc(
      'admin_set_product_featured',
      params: {'p_product_id': productId, 'p_is_featured': isFeatured},
    );
  }

  /// Lists the active branches the dashboard may configure.
  @override
  Future<List<Map<String, dynamic>>> loadBranches() async {
    final rows = await _supabase
        .from('branches')
        .select('id, code, name_ar, name_en, is_active')
        .eq('is_active', true)
        .order('code');
    return (rows as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// Reads the branch-specific pricing rows of a product.
  @override
  Future<List<Map<String, dynamic>>> loadBranchProductPricing(
    String productId,
  ) async {
    final rows = await _supabase
        .from('branch_product_pricing')
        .select('*')
        .eq('product_id', productId);
    return (rows as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// Writes the branch-specific discount of a product for one branch.
  ///
  /// The price override and availability columns are left untouched when they
  /// are not supplied, so a discount edit never resets the branch price.
  @override
  Future<void> saveBranchProductDiscount({
    required String branchId,
    required String productId,
    double? discountPercentage,
    DateTime? discountStartsAt,
    DateTime? discountEndsAt,
    required bool useGeneralDiscount,
  }) async {
    await _supabase.from('branch_product_pricing').upsert(<String, dynamic>{
      'branch_id': branchId,
      'product_id': productId,
      'discount_percentage': discountPercentage,
      'discount_starts_at': discountStartsAt?.toIso8601String(),
      'discount_ends_at': discountEndsAt?.toIso8601String(),
      'use_general_discount': useGeneralDiscount,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------------
  // The pictures of a product.
  //
  // The rows live in catalog.product_images. The table is writable by the
  // staff that may write products (its own row level security decides), so
  // no extra database function is needed for the dashboard.
  // ---------------------------------------------------------------------------

  /// The pictures of a product, in the order they are shown.
  ///
  /// The tables are addressed without their schema: PostgREST exposes the
  /// tables of the exposed schemas under their own name, and the address
  /// with the schema (`catalog.product_images`) is answered with a 404.
  @override
  Future<List<AdminProductImage>> loadProductImages(
    String productId, {
    String? fallbackImageUrl,
  }) async {
    final images = await _loadProductImageRows(productId);
    final fallbackUrl = fallbackImageUrl?.trim();
    if (images.isNotEmpty || fallbackUrl == null || fallbackUrl.isEmpty) {
      return images;
    }

    // Older product records may have an image_url without a gallery row.
    // Import that image as the primary gallery item so it can be managed here.
    try {
      await _supabase.from('product_images').insert({
        'product_id': productId,
        'image_url': fallbackUrl,
        'sort_order': 0,
        'is_primary': true,
      });
    } on PostgrestException {
      // A second opener may have imported it first. Return the row if it now
      // exists; otherwise preserve the original permission or database error.
      final refreshed = await _loadProductImageRows(productId);
      if (refreshed.isNotEmpty) return refreshed;
      rethrow;
    }
    return _loadProductImageRows(productId);
  }

  Future<List<AdminProductImage>> _loadProductImageRows(
    String productId,
  ) async {
    try {
      final rows = await _supabase
          .from('product_images')
          .select(_productImageColumns)
          .eq('product_id', productId)
          .order('sort_order', ascending: true);
      return _imagesFrom(rows);
    } on PostgrestException catch (error) {
      // The settings columns arrive with the migration that adds them. Until
      // it is applied the pictures are read without them and keep the safe
      // default, so the dashboard still works.
      if (!_isMissingColumn(error)) rethrow;

      final rows = await _supabase
          .from('product_images')
          .select(_productImageColumnsWithoutSettings)
          .eq('product_id', productId)
          .order('sort_order', ascending: true);
      return _imagesFrom(rows);
    }
  }

  List<AdminProductImage> _imagesFrom(List<dynamic> rows) {
    return rows
        .whereType<Map<String, dynamic>>()
        .map(AdminProductImage.fromRow)
        .toList(growable: false);
  }

  /// True when the database does not know the settings columns yet.
  bool _isMissingColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('fit') || message.contains('alignment');
  }

  /// Adds a picture to a product.
  ///
  /// The first picture of a product becomes the primary one, so the cards
  /// and the lists always show something. The picture of the product itself
  /// is kept in step by the database.
  @override
  Future<List<AdminProductImage>> addProductImage({
    required String productId,
    required String imageUrl,
  }) async {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      throw AdminProductException(S.imageUrlMissing);
    }

    final current = await loadProductImages(productId);
    final isFirst = current.isEmpty;

    await _supabase.from('product_images').insert({
      'product_id': productId,
      'image_url': url,
      'sort_order': current.length,
      'is_primary': isFirst,
    });

    return loadProductImages(productId);
  }

  /// Points a picture at another url, keeping the old one when the write
  /// fails.
  ///
  /// The display settings of the picture are written with it, so a picture
  /// keeps the way it is shown.
  @override
  Future<List<AdminProductImage>> updateProductImage({
    required AdminProductImage image,
    required String imageUrl,
    BoxFit? fit,
    Alignment? alignment,
  }) async {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      throw AdminProductException(S.imageUrlMissing);
    }

    final changes = <String, dynamic>{'image_url': url};
    if (fit != null) changes['fit'] = fitName(fit);
    if (alignment != null) changes['alignment'] = alignmentName(alignment);

    await _supabase.from('product_images').update(changes).eq('id', image.id);

    return loadProductImages(image.productId);
  }

  /// Changes the display settings of one picture.
  ///
  /// The file of the picture is not touched: only the way it is shown.
  @override
  Future<List<AdminProductImage>> updateProductImageSettings({
    required AdminProductImage image,
    BoxFit? fit,
    Alignment? alignment,
  }) async {
    final changes = <String, dynamic>{};
    if (fit != null) changes['fit'] = fitName(fit);
    if (alignment != null) changes['alignment'] = alignmentName(alignment);
    if (changes.isEmpty) return loadProductImages(image.productId);

    await _supabase.from('product_images').update(changes).eq('id', image.id);

    return loadProductImages(image.productId);
  }

  /// Changes the display settings of every picture of a product.
  ///
  /// The files of the pictures are not touched, and the pictures that are not
  /// part of the product are not touched either.
  @override
  Future<List<AdminProductImage>> applyProductImageSettings({
    required String productId,
    BoxFit? fit,
    Alignment? alignment,
  }) async {
    final changes = <String, dynamic>{};
    if (fit != null) changes['fit'] = fitName(fit);
    if (alignment != null) changes['alignment'] = alignmentName(alignment);
    if (changes.isEmpty) return loadProductImages(productId);

    await _supabase
        .from('product_images')
        .update(changes)
        .eq('product_id', productId);

    return loadProductImages(productId);
  }

  /// Removes a picture of a product.
  ///
  /// The product keeps a picture: when the primary one goes, the next picture
  /// takes its place.
  @override
  Future<List<AdminProductImage>> deleteProductImage(
    AdminProductImage image,
  ) async {
    await _supabase.from('product_images').delete().eq('id', image.id);

    final remaining = await loadProductImages(image.productId);
    if (image.isPrimary && remaining.isNotEmpty) {
      await _supabase
          .from('product_images')
          .update({'is_primary': true})
          .eq('id', remaining.first.id);
    }

    // The file of the picture goes only when no other picture uses it.
    await _removeFileIfUnused(image.imageUrl);

    return loadProductImages(image.productId);
  }

  /// Makes a picture the primary one of its product.
  ///
  /// The move happens in the database, in one transaction, so the product is
  /// never left with two primary pictures or with none. The picture of the
  /// product follows the new primary one.
  @override
  Future<List<AdminProductImage>> setPrimaryProductImage(
    AdminProductImage image,
  ) async {
    final response = await _supabase.rpc(
      'admin_set_primary_product_image',
      params: {'p_product_id': image.productId, 'p_image_id': image.id},
    );

    if (_asMap(response).isEmpty) {
      throw AdminProductException(S.imagePrimaryFailed);
    }

    return loadProductImages(image.productId);
  }

  /// Uploads a picture of a product and records it.
  ///
  /// The file is uploaded first and the row is written afterwards. When the
  /// row cannot be written the uploaded file is removed again, so the bucket
  /// never keeps a picture that no product points at.
  ///
  /// [onPhase] tells the caller which step is running.
  @override
  Future<List<AdminProductImage>> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    _checkImage(bytes, contentType);
    final path = _productImagePath(productId, fileName);

    onPhase?.call(AdminImageUploadPhase.uploading);
    await _supabase.storage
        .from(productImagesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    onPhase?.call(AdminImageUploadPhase.saving);
    try {
      return await addProductImage(
        productId: productId,
        imageUrl: _publicImageUrl(path),
      );
    } catch (error) {
      await _removeFile(path);
      rethrow;
    }
  }

  /// Replaces a picture of a product with a new file.
  ///
  /// The old picture stays untouched until the new file is uploaded and its
  /// row is written.
  @override
  Future<List<AdminProductImage>> replaceProductImageWithFile({
    required AdminProductImage image,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    BoxFit? fit,
    Alignment? alignment,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    _checkImage(bytes, contentType);
    final path = _productImagePath(image.productId, fileName);

    onPhase?.call(AdminImageUploadPhase.uploading);
    await _supabase.storage
        .from(productImagesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    onPhase?.call(AdminImageUploadPhase.saving);
    try {
      final images = await updateProductImage(
        image: image,
        imageUrl: _publicImageUrl(path),
        fit: fit,
        alignment: alignment,
      );
      // The old file leaves the bucket only now that the new picture is
      // written and no other picture points at it.
      await _removeFileIfUnused(image.imageUrl);
      return images;
    } catch (error) {
      await _removeFile(path);
      rethrow;
    }
  }

  /// The path of a picture inside the bucket.
  ///
  /// Every picture of a product lives in its own folder, so the policies of
  /// the bucket can keep the pictures of the catalogue apart from the rest.
  String _productImagePath(String productId, String fileName) {
    final extension = _extensionOf(fileName);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(1 << 32).toRadixString(16);
    return 'products/$productId/${stamp}_$random$extension';
  }

  /// The public url of a file of the bucket.
  String _publicImageUrl(String path) {
    return '${AppConfig.supabaseUrl}/storage/v1/object/public/'
        '$productImagesBucket/$path';
  }

  /// The path of a file of the bucket, when the url points at it.
  String? _pathOf(String imageUrl) {
    final marker = '/$productImagesBucket/';
    final index = imageUrl.indexOf(marker);
    if (index < 0) return null;
    return imageUrl.substring(index + marker.length);
  }

  String _extensionOf(String fileName) {
    final name = fileName.trim().toLowerCase();
    for (final extension in const <String>['.jpg', '.jpeg', '.png', '.webp']) {
      if (name.endsWith(extension)) {
        return extension == '.jpeg' ? '.jpg' : extension;
      }
    }
    return '.jpg';
  }

  /// The picture must be a format the bucket accepts and must not be bigger
  /// than the bucket allows.
  void _checkImage(Uint8List bytes, String contentType) {
    if (!productImageTypes.contains(contentType)) {
      throw AdminProductException(S.imageMustBeFormat);
    }
    if (bytes.isEmpty) {
      throw AdminProductException(S.imageIsEmpty);
    }
    if (bytes.length > maxProductImageBytes) {
      throw AdminProductException(S.imageTooLarge);
    }
  }

  /// Removes a file of the bucket, ignoring a failure: the caller keeps the
  /// picture it already has.
  Future<void> _removeFile(String path) async {
    try {
      await _supabase.storage.from(productImagesBucket).remove([path]);
    } catch (_) {
      // Cleanup only: the picture that matters is already written.
    }
  }

  /// Removes the file of a picture when no other picture uses it.
  Future<void> _removeFileIfUnused(String imageUrl) async {
    final path = _pathOf(imageUrl);
    if (path == null) return;

    final used = await _supabase
        .from('product_images')
        .select('id')
        .eq('image_url', imageUrl);
    if ((used as List<dynamic>).isNotEmpty) return;

    await _removeFile(path);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }
}
