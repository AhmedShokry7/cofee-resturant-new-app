import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_state.dart';

class AdminCategoryCubit extends Cubit<AdminCategoryState> {
  AdminCategoryCubit({AdminProductRepository? repository})
    : _repository = repository ?? AdminProductRepository(),
      super(const AdminCategoryState());

  final AdminProductRepository _repository;

  AdminProductRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminCategoryStatus.loading, clearError: true));
    try {
      final snapshot = await _repository.loadCatalog();
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
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminCategoryStatus.failure,
          errorMessage: '$error',
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
  }

  Future<AdminCategory> updateCategory({
    required String categoryId,
    required String nameAr,
    required String nameEn,
    String? descriptionAr,
    String? descriptionEn,
  }) async {
    final updated = await _repository.updateCategory(
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
    await _repository.deleteCategory(categoryId);
    emit(
      state.copyWith(
        categories: state.categories
            .where((c) => c.id != categoryId)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<void> toggleActive(AdminCategory category) async {
    final next = !category.isActive;
    await _repository.setCategoryActive(category.id, next);
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
    await _repository.updateCategoryImage(categoryId, imageUrl);
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
    return imageUrl;
  }

  Future<String> uploadCategoryImage({
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final url = await _repository.uploadCategoryImage(
      categoryId: categoryId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    await updateCategoryImage(categoryId, url);
    return url;
  }

  Future<void> deleteCategoryImageFile(String? imageUrl) async {
    await _repository.deleteCategoryImageFile(imageUrl);
  }
}
