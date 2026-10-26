import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';

/// تغيير حالة تيكيت المطبخ بعد فحص القاعدة.
class SetTicketStatusUseCase {
  const SetTicketStatusUseCase(this._repository);

  final KitchenRepository _repository;

  Future<KitchenMutationOutcome> call(
    String ticketId,
    KitchenTicketStatus status,
  ) => _repository.setTicketStatus(ticketId, status);
}
