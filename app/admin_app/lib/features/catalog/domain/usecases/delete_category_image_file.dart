import 'package:admin_app/core/catalog/category_repository.dart';

class DeleteCategoryImageFileUseCase {
  const DeleteCategoryImageFileUseCase(this._repository);

  final CategoryRepository _repository;

  Future<void> call(String? imageUrl) =>
      _repository.deleteCategoryImageFile(imageUrl);
}
