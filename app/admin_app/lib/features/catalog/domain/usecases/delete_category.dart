import 'package:admin_app/core/catalog/category_repository.dart';

class DeleteCategoryUseCase {
  const DeleteCategoryUseCase(this._repository);

  final CategoryRepository _repository;

  Future<void> call(String categoryId) =>
      _repository.deleteCategory(categoryId);
}
