import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/catalog/category_repository.dart';

class CreateCategoryUseCase {
  const CreateCategoryUseCase(this._repository);

  final CategoryRepository _repository;

  Future<AdminCategory> call({
    required String nameAr,
    required String nameEn,
    String? descriptionAr,
    String? descriptionEn,
  }) => _repository.createCategory(
    nameAr: nameAr,
    nameEn: nameEn,
    descriptionAr: descriptionAr,
    descriptionEn: descriptionEn,
  );
}
