import 'package:admin_app/core/catalog/category_repository.dart';

class SetCategoryActiveUseCase {
  const SetCategoryActiveUseCase(this._repository);

  final CategoryRepository _repository;

  Future<void> call(String categoryId, bool isActive) =>
      _repository.setCategoryActive(categoryId, isActive);
}
