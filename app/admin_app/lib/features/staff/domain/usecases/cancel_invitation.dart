import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// سحب دعوة لم تُقبل بعد.
class CancelInvitationUseCase {
  const CancelInvitationUseCase(this._repository);

  final StaffRepository _repository;

  Future<StaffInviteOutcome> call(String invitationId) =>
      _repository.cancelInvitation(invitationId);
}
