import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/models/admin_product_image.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_state.dart';

/// The products the dashboard edits.
///
/// Every change of the catalogue goes through this cubit, so the widgets only
/// read the state and ask for an action.
class AdminProductCubit extends Cubit<AdminProductState> {
  AdminProductCubit({AdminProductRepository? repository})
    : _repository = repository ?? AdminProductRepository(),
      super(const AdminProductState());

  final AdminProductRepository _repository;

  /// Exposes a read of the catalogue for workflows that need every matching row,
  /// such as import and export, without changing the paged state of the page.
  Future<AdminCatalogSnapshot> loadCatalogSnapshot({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) {
    return _repository.loadCatalog(
      branchId: branchId,
      limit: limit,
      offset: offset,
      search: search,
    );
  }

  /// How many products one page holds.
  static const int pageSize = 20;

  /// Loads the first page of the catalogue of the branch the dashboard
  /// reviews.
  Future<void> load({String search = ''}) async {
    emit(state.copyWith(status: AdminProductStatus.loading, clearError: true));
    try {
      final snapshot = await _repository.loadCatalog(
        limit: pageSize,
        search: search,
      );
      emit(
        state.copyWith(
          status: AdminProductStatus.ready,
          products: snapshot.products,
          categories: snapshot.categories,
          branchId: snapshot.branchId,
          total: snapshot.total,
          loadedCount: snapshot.products.length,
          selectedIds: const <String>{},
          search: search,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminProductStatus.failure,
          errorMessage: _messageFor(error),
        ),
      );
    }
  }

  /// Loads the next page of the catalogue.
  ///
  /// The page is asked for only when the admin reaches the end of the list,
  /// so the catalogue never arrives in one piece.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    if (state.status == AdminProductStatus.loading) return;

    emit(state.copyWith(isLoadingMore: true));
    try {
      final snapshot = await _repository.loadCatalog(
        limit: pageSize,
        offset: state.loadedCount,
        search: state.search,
      );
      emit(
        state.copyWith(
          products: <AdminProduct>[...state.products, ...snapshot.products],
          categories: snapshot.categories,
          total: snapshot.total,
          loadedCount: state.loadedCount + snapshot.products.length,
          clearLoadingMore: true,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          clearLoadingMore: true,
          errorMessage: _writeMessage(error),
        ),
      );
    }
  }

  /// Looks for the products that carry the word of the admin.
  ///
  /// The search runs on the database, so it also reaches the products that
  /// are not on the page yet.
  Future<void> search(String query) async {
    final term = query.trim();
    if (term == state.search && state.status == AdminProductStatus.ready) {
      return;
    }

    emit(state.copyWith(clearError: true));
    try {
      final snapshot = await _repository.loadCatalog(
        limit: pageSize,
        search: term,
      );
      emit(
        state.copyWith(
          status: AdminProductStatus.ready,
          products: snapshot.products,
          categories: snapshot.categories,
          branchId: snapshot.branchId,
          total: snapshot.total,
          loadedCount: snapshot.products.length,
          selectedIds: const <String>{},
          search: term,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: _writeMessage(error)));
    }
  }

  /// Writes the product the admin edited. A draft becomes a new row.
  Future<void> saveProduct(AdminProduct product) async {
    emit(state.copyWith(savingProductId: product.id, clearError: true));
    try {
      final saved = await _repository.saveProduct(
        product,
        branchId: state.branchId,
      );
      final products = <AdminProduct>[...state.products];
      final index = products.indexWhere((entry) => entry.id == product.id);
      if (index >= 0) {
        products[index] = saved;
      } else {
        products.add(saved);
      }
      emit(
        state.copyWith(
          products: products,
          // A draft that is written becomes a row of the database.
          total: product.isDraft ? state.total + 1 : state.total,
          loadedCount: product.isDraft
              ? state.loadedCount + 1
              : state.loadedCount,
          clearSaving: true,
          clearError: true,
          notice: product.isDraft ? S.productWasAdded : S.saved,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(clearSaving: true, errorMessage: _writeMessage(error)),
      );
      rethrow;
    }
  }

  /// Removes the product from the catalogue.
  Future<void> deleteProduct(String productId) async {
    try {
      await _repository.deleteProduct(productId);
      emit(
        state.copyWith(
          products: state.products
              .where((product) => product.id != productId)
              .toList(growable: false),
          selectedIds: state.selectedIds.difference(<String>{productId}),
          total: state.total > 0 ? state.total - 1 : 0,
          loadedCount:
              state.loadedCount > 0 &&
                  state.products.any((product) => product.id == productId)
              ? state.loadedCount - 1
              : state.loadedCount,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: _writeMessage(error)));
    }
  }

  /// Creates a category and hands it back, so the card can select it.
  Future<AdminCategory?> createCategory({
    required String nameAr,
    required String nameEn,
    String? descriptionAr,
    String? descriptionEn,
  }) async {
    try {
      final category = await _repository.createCategory(
        nameAr: nameAr,
        nameEn: nameEn,
        descriptionAr: descriptionAr,
        descriptionEn: descriptionEn,
      );
      emit(
        state.copyWith(
          categories: <AdminCategory>[...state.categories, category],
          clearError: true,
        ),
      );
      return category;
    } catch (error) {
      emit(state.copyWith(errorMessage: _writeMessage(error)));
      return null;
    }
  }

  /// Marks the product as featured, or clears the mark.
  Future<void> toggleFeatured(AdminProduct product) async {
    final next = !product.isFeatured;
    try {
      await _repository.setFeatured(product.id, next);
      emit(
        state.copyWith(
          products: _replace(product.copyWith(isFeatured: next)),
          clearError: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: _writeMessage(error)));
    }
  }

  /// Picks the product for a bulk action, or drops it from the selection.
  void toggleSelection(String productId) {
    if (state.products.any(
      (product) => product.id == productId && product.isDraft,
    )) {
      return;
    }
    final selected = <String>{...state.selectedIds};
    if (!selected.remove(productId)) selected.add(productId);
    emit(state.copyWith(selectedIds: selected));
  }

  /// Drops every product from the selection.
  void clearSelection() {
    emit(state.copyWith(selectedIds: const <String>{}));
  }

  /// Selects every product matching the current search, including products
  /// that are not loaded into the visible pages yet.
  Future<void> selectAllProducts() async {
    if (state.isSelectingAll || state.isDeletingSelected || state.total == 0) {
      return;
    }

    final search = state.search;
    final selected = <String>{...state.selectedIds};
    selected.addAll(
      state.products
          .where((product) => !product.isDraft)
          .map((product) => product.id),
    );
    var offset = state.loadedCount;
    var total = state.total;
    emit(state.copyWith(isSelectingAll: true, clearError: true));

    try {
      while (offset < total) {
        final snapshot = await _repository.loadCatalog(
          limit: pageSize,
          offset: offset,
          search: search,
        );
        total = snapshot.total;
        if (snapshot.products.isEmpty) break;
        selected.addAll(
          snapshot.products
              .where((product) => !product.isDraft)
              .map((product) => product.id),
        );
        offset += snapshot.products.length;
      }
      if (offset < total) {
        throw AdminProductException(S.notAllProductsLoaded);
      }
      emit(
        state.copyWith(
          selectedIds: selected,
          clearSelectingAll: true,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          clearSelectingAll: true,
          errorMessage: _writeMessage(error),
        ),
      );
    }
  }

  /// Deletes selected products one by one, keeping failed IDs selected so
  /// they can be retried without repeating successful deletions.
  Future<void> deleteSelectedProducts() async {
    if (state.isDeletingSelected || state.selectedIds.isEmpty) return;

    final requested = <String>{...state.selectedIds};
    final deleted = <String>{};
    var failures = 0;
    emit(state.copyWith(isDeletingSelected: true, clearError: true));

    for (final productId in requested) {
      try {
        await _repository.deleteProduct(productId);
        deleted.add(productId);
      } catch (_) {
        failures++;
      }
    }

    final current = state;
    final removedFromLoaded = current.products
        .where((product) => deleted.contains(product.id))
        .length;
    emit(
      current.copyWith(
        products: current.products
            .where((product) => !deleted.contains(product.id))
            .toList(growable: false),
        selectedIds: current.selectedIds.difference(deleted),
        total: (current.total - deleted.length).clamp(0, current.total),
        loadedCount: (current.loadedCount - removedFromLoaded).clamp(
          0,
          current.loadedCount,
        ),
        clearDeletingSelected: true,
        clearError: failures == 0,
        notice: failures == 0 ? S.productsDeleted(deleted.length) : null,
        errorMessage: failures == 0 ? null : S.productsDeletePartial(failures),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // The pictures of a product.
  // ---------------------------------------------------------------------------

  /// The pictures of a product, in the order they are shown.
  Future<List<AdminProductImage>> loadProductImages(
    String productId, {
    String? fallbackImageUrl,
  }) {
    return _repository.loadProductImages(
      productId,
      fallbackImageUrl: fallbackImageUrl,
    );
  }

  /// Adds a picture to a product and keeps the card in step with it.
  Future<List<AdminProductImage>> addProductImage({
    required String productId,
    required String imageUrl,
  }) async {
    final images = await _repository.addProductImage(
      productId: productId,
      imageUrl: imageUrl,
    );
    _refreshProductImage(productId, images);
    return images;
  }

  /// Adds a picture to a product from a file of the device or from a link.
  ///
  /// [onPhase] tells the gallery which step of the write is running.
  Future<List<AdminProductImage>> addProductImageFrom({
    required String productId,
    required ProductImageSource source,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    final images = source.isLink
        ? await _repository.addProductImage(
            productId: productId,
            imageUrl: source.url!,
          )
        : await _repository.uploadProductImage(
            productId: productId,
            bytes: source.bytes!,
            fileName: source.fileName!,
            contentType: source.contentType!,
            onPhase: onPhase,
          );
    _refreshProductImage(productId, images);
    return images;
  }

  /// Replaces a picture of a product from a file of the device or a link.
  Future<List<AdminProductImage>> replaceProductImageFrom({
    required AdminProductImage image,
    required ProductImageSource source,
    BoxFit? fit,
    Alignment? alignment,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    final images = source.isLink
        ? await _repository.updateProductImage(
            image: image,
            imageUrl: source.url!,
            fit: fit,
            alignment: alignment,
          )
        : await _repository.replaceProductImageWithFile(
            image: image,
            bytes: source.bytes!,
            fileName: source.fileName!,
            contentType: source.contentType!,
            fit: fit,
            alignment: alignment,
            onPhase: onPhase,
          );
    _refreshProductImage(image.productId, images);
    return images;
  }

  /// Changes the display settings of one picture.
  ///
  /// The file of the picture is not touched.
  Future<List<AdminProductImage>> updateProductImageSettings({
    required AdminProductImage image,
    BoxFit? fit,
    Alignment? alignment,
  }) async {
    final images = await _repository.updateProductImageSettings(
      image: image,
      fit: fit,
      alignment: alignment,
    );
    _refreshProductImage(image.productId, images);
    return images;
  }

  /// Changes the display settings of every picture of a product.
  Future<List<AdminProductImage>> applyProductImageSettings({
    required String productId,
    BoxFit? fit,
    Alignment? alignment,
  }) async {
    final images = await _repository.applyProductImageSettings(
      productId: productId,
      fit: fit,
      alignment: alignment,
    );
    _refreshProductImage(productId, images);
    return images;
  }

  /// Points a picture at another url.
  Future<List<AdminProductImage>> updateProductImage({
    required AdminProductImage image,
    required String imageUrl,
  }) async {
    final images = await _repository.updateProductImage(
      image: image,
      imageUrl: imageUrl,
    );
    _refreshProductImage(image.productId, images);
    return images;
  }

  /// Removes a picture of a product.
  Future<List<AdminProductImage>> deleteProductImage(
    AdminProductImage image,
  ) async {
    final images = await _repository.deleteProductImage(image);
    _refreshProductImage(image.productId, images);
    return images;
  }

  /// Makes a picture the primary one of its product.
  Future<List<AdminProductImage>> setPrimaryProductImage(
    AdminProductImage image,
  ) async {
    final images = await _repository.setPrimaryProductImage(image);
    _refreshProductImage(image.productId, images);
    return images;
  }

  /// Shows the primary picture of the product on its card.
  void _refreshProductImage(String productId, List<AdminProductImage> images) {
    AdminProductImage? primary;
    for (final image in images) {
      if (image.isPrimary) {
        primary = image;
        break;
      }
    }
    primary ??= images.isEmpty ? null : images.first;

    final products = state.products
        .map(
          (product) => product.id == productId
              ? product.copyWith(
                  imageUrl: primary?.imageUrl,
                  clearImageUrl: primary == null,
                  imageFit: primary?.fit ?? BoxFit.cover,
                  imageAlignment: primary?.alignment ?? Alignment.center,
                )
              : product,
        )
        .toList(growable: false);
    emit(state.copyWith(products: products));
  }

  /// Drops the message that told the admin the last action worked.
  void clearNotice() {
    emit(state.copyWith(clearNotice: true));
  }

  /// Drops the message that told the admin the last action failed.
  void clearError() {
    if (state.errorMessage == null) return;
    emit(state.copyWith(clearError: true));
  }

  List<AdminProduct> _replace(AdminProduct product) {
    return state.products
        .map((entry) => entry.id == product.id ? product : entry)
        .toList(growable: false);
  }

  String _messageFor(Object error) {
    if (error is AdminProductException) return error.message;
    if (error is PostgrestException) return error.message;
    if (error is StateError) {
      return S.supabaseNotConfigured;
    }
    return S.catalogueUnreachable;
  }

  /// Turns the words of the database into a message the admin understands.
  Future<List<Map<String, dynamic>>> loadBranches() =>
      _repository.loadBranches();

  Future<List<Map<String, dynamic>>> loadBranchProductPricing(
    String productId,
  ) => _repository.loadBranchProductPricing(productId);

  Future<void> saveBranchProductDiscount({
    required String branchId,
    required String productId,
    double? discountPercentage,
    DateTime? discountStartsAt,
    DateTime? discountEndsAt,
    required bool useGeneralDiscount,
  }) => _repository.saveBranchProductDiscount(
    branchId: branchId,
    productId: productId,
    discountPercentage: discountPercentage,
    discountStartsAt: discountStartsAt,
    discountEndsAt: discountEndsAt,
    useGeneralDiscount: useGeneralDiscount,
  );

  String _writeMessage(Object error) {
    if (error is AdminProductException) return error.message;
    final text = error is PostgrestException ? error.message : '$error';
    final lower = text.toLowerCase();
    if (lower.contains('arabic name')) return S.productNeedsName;
    if (lower.contains('unknown category')) return S.productNeedsCategory;
    if (lower.contains('compare price')) return S.compareAtMustBeHigher;
    if (lower.contains('permission')) return S.couldNotSaveProduct;
    return S.couldNotSaveProduct;
  }
}
