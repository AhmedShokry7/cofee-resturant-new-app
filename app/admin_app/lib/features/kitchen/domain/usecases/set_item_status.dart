import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';

/// تغيير حالة سطر من سطور التيكيت بعد فحص القاعدة.
class SetItemStatusUseCase {
  const SetItemStatusUseCase(this._repository);

  final KitchenRepository _repository;

  Future<KitchenMutationOutcome> call(
    String itemId,
    KitchenItemStatus status,
  ) => _repository.setItemStatus(itemId, status);
}
