import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/catalog/category_repository.dart';

class UpdateCategoryUseCase {
  const UpdateCategoryUseCase(this._repository);

  final CategoryRepository _repository;

  Future<AdminCategory> call({
    required String categoryId,
    required String nameAr,
    required String nameEn,
    String? descriptionAr,
    String? descriptionEn,
  }) => _repository.updateCategory(
    categoryId: categoryId,
    nameAr: nameAr,
    nameEn: nameEn,
    descriptionAr: descriptionAr,
    descriptionEn: descriptionEn,
  );
}
