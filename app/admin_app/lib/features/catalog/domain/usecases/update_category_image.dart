import 'package:admin_app/core/catalog/category_repository.dart';

class UpdateCategoryImageUseCase {
  const UpdateCategoryImageUseCase(this._repository);

  final CategoryRepository _repository;

  Future<void> call(String categoryId, String? imageUrl) =>
      _repository.updateCategoryImage(categoryId, imageUrl);
}
