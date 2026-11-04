import 'package:admin_app/features/option_groups/domain/repositories/product_option_repository.dart';

/// كتابة زيادة خيار لمشروب بعينه، أو محو تجاوزها.
class SaveProductOptionPriceUseCase {
  const SaveProductOptionPriceUseCase(this._repository);

  final ProductOptionRepository _repository;

  Future<void> call(String productId, String valueId, double? delta) =>
      _repository.setValuePrice(productId, valueId, delta);
}
