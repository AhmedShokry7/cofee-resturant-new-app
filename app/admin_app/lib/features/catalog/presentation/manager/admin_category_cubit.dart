import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/features/catalog/di/catalog_dependencies.dart';
import 'package:admin_app/features/catalog/domain/usecases/create_category.dart';
import 'package:admin_app/features/catalog/domain/usecases/delete_category.dart';
import 'package:admin_app/features/catalog/domain/usecases/delete_category_image_file.dart';
import 'package:admin_app/features/catalog/domain/usecases/load_catalog.dart';
import 'package:admin_app/features/catalog/domain/usecases/set_category_active.dart';
import 'package:admin_app/features/catalog/domain/usecases/update_category.dart';
import 'package:admin_app/features/catalog/domain/usecases/update_category_image.dart';
import 'package:admin_app/features/catalog/domain/usecases/upload_category_image.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_state.dart';

class AdminCategoryCubit extends Cubit<AdminCategoryState> {
  AdminCategoryCubit({CatalogData? repository})
    : this._withUseCases(repository ?? CatalogDependencies.catalog);

  AdminCategoryCubit._withUseCases(CatalogData repository)
    : _loadCatalog = LoadCatalogUseCase(repository),
      _createCategory = CreateCategoryUseCase(repository),
      _updateCategory = UpdateCategoryUseCase(repository),
      _deleteCategory = DeleteCategoryUseCase(repository),
      _setCategoryActive = SetCategoryActiveUseCase(repository),
      _updateCategoryImage = UpdateCategoryImageUseCase(repository),
      _uploadCategoryImage = UploadCategoryImageUseCase(repository),
      _deleteCategoryImageFile = DeleteCategoryImageFileUseCase(repository),
      super(const AdminCategoryState());

  final LoadCatalogUseCase _loadCatalog;
  final CreateCategoryUseCase _createCategory;
  final UpdateCategoryUseCase _updateCategory;
  final DeleteCategoryUseCase _deleteCategory;
  final SetCategoryActiveUseCase _setCategoryActive;
  final UpdateCategoryImageUseCase _updateCategoryImage;
  final UploadCategoryImageUseCase _uploadCategoryImage;
  final DeleteCategoryImageFileUseCase _deleteCategoryImageFile;

  Future<void> load() async {
    emit(state.copyWith(status: AdminCategoryStatus.loading, clearError: true));
    try {
      final snapshot = await _loadCatalog();
      final counts = <String, int>{};
      for (final product in snapshot.products) {
        final categoryId = product.categoryId;
        if (categoryId == null || categoryId.isEmpty) continue;
        counts[categoryId] = (counts[categoryId] ?? 0) + 1;
      }
      final categories = snapshot.categories
          .map(
            (category) => category.copyWith(
              productCount: counts[category.id] ?? category.productCount,
            ),
          )
          .toList(growable: false);
      emit(
        state.copyWith(
          status: AdminCategoryStatus.ready,
          categories: categories,
          selectedIds: const <String>{},
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminCategoryStatus.failure,
          errorMessage: adminErrorMessage(error),
        ),
      );
    }
  }

  Future<AdminCategory> createCategory({
    required String nameAr,
    required String nameEn,
    String? descriptionAr,
    String? descriptionEn,
  }) async {
    final category = await _createCategory(
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
  }

  Future<AdminCategory> updateCategory({
    required String categoryId,
    required String nameAr,
    required String nameEn,
    String? descriptionAr,
    String? descriptionEn,
  }) async {
    final updated = await _updateCategory(
      categoryId: categoryId,
      nameAr: nameAr,
      nameEn: nameEn,
      descriptionAr: descriptionAr,
      descriptionEn: descriptionEn,
    );
    emit(
      state.copyWith(
        categories: state.categories
            .map((c) => c.id == categoryId ? updated : c)
            .toList(growable: false),
        clearError: true,
      ),
    );
    return updated;
  }

  Future<void> deleteCategory(String categoryId) async {
    await _deleteCategory(categoryId);
    emit(
      state.copyWith(
        categories: state.categories
            .where((c) => c.id != categoryId)
            .toList(growable: false),
        selectedIds: state.selectedIds.difference(<String>{categoryId}),
        clearError: true,
      ),
    );
  }

  /// Picks the category for a bulk action, or drops it from the selection.
  void toggleSelection(String categoryId) {
    final selected = <String>{...state.selectedIds};
    if (!selected.remove(categoryId)) selected.add(categoryId);
    emit(state.copyWith(selectedIds: selected));
  }

  /// Drops every category from the selection.
  void clearSelection() {
    emit(state.copyWith(selectedIds: const <String>{}));
  }

  /// Selects every category whose id is in [ids], keeping the current picks.
  void selectMany(Iterable<String> ids) {
    emit(state.copyWith(selectedIds: <String>{...state.selectedIds, ...ids}));
  }

  /// Deletes the selected categories one by one, keeping the failed ones
  /// selected so the admin can retry without repeating the successful ones.
  Future<({int deleted, int failed})> deleteSelected() async {
    if (state.isDeletingSelected || state.selectedIds.isEmpty) {
      return (deleted: 0, failed: 0);
    }

    final requested = <String>{...state.selectedIds};
    final deleted = <String>{};
    var failures = 0;
    emit(state.copyWith(isDeletingSelected: true, clearError: true));

    for (final categoryId in requested) {
      try {
        await _deleteCategory(categoryId);
        deleted.add(categoryId);
      } catch (_) {
        failures++;
      }
    }

    final current = state;
    emit(
      current.copyWith(
        categories: current.categories
            .where((c) => !deleted.contains(c.id))
            .toList(growable: false),
        selectedIds: current.selectedIds.difference(deleted),
        isDeletingSelected: false,
        clearError: true,
      ),
    );
    return (deleted: deleted.length, failed: failures);
  }

  Future<void> toggleActive(AdminCategory category) async {
    final next = !category.isActive;
    await _setCategoryActive(category.id, next);
    emit(
      state.copyWith(
        categories: state.categories
            .map((c) => c.id == category.id ? c.copyWith(isActive: next) : c)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<String?> updateCategoryImage(
    String categoryId,
    String? imageUrl,
  ) async {
    await _updateCategoryImage(categoryId, imageUrl);
    _showImage(categoryId, imageUrl);
    return imageUrl;
  }

  /// Puts the picture of a category into the list the admin sees.
  void _showImage(String categoryId, String? imageUrl) {
    emit(
      state.copyWith(
        categories: state.categories
            .map(
              (c) => c.id == categoryId
                  ? c.copyWith(
                      imageUrl: imageUrl,
                      clearImageUrl: imageUrl == null || imageUrl.isEmpty,
                    )
                  : c,
            )
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<String> uploadCategoryImage({
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final url = await _uploadCategoryImage(
      categoryId: categoryId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    // The write of the row happened with the file: writing it a second time
    // would send the same change to the database twice.
    _showImage(categoryId, url);
    return url;
  }

  Future<void> deleteCategoryImageFile(String? imageUrl) async {
    await _deleteCategoryImageFile(imageUrl);
  }
}
