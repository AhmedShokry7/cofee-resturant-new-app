import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';
import 'package:admin_app/features/option_groups/domain/repositories/product_option_repository.dart';

/// قراءة المجموعات التي تسري على مشروب واحد بأسعاره عنده.
class LoadProductOptionsUseCase {
  const LoadProductOptionsUseCase(this._repository);

  final ProductOptionRepository _repository;

  Future<List<AdminProductOptionGroup>> call(String productId) =>
      _repository.loadForProduct(productId);
}
