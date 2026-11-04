import 'package:admin_app/features/option_groups/domain/repositories/product_option_repository.dart';

/// ربط مجموعة أحجام أو إضافات بمشروب، أو فصلها عنه.
class SetProductOptionGroupUseCase {
  const SetProductOptionGroupUseCase(this._repository);

  final ProductOptionRepository _repository;

  Future<void> call(String productId, String groupId, bool attached) =>
      _repository.setGroupAttached(productId, groupId, attached);
}
