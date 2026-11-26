import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// حذف سجل دعوة بعد أن يؤكد المدير الإجراء.
class DeleteInvitationUseCase {
  const DeleteInvitationUseCase(this._repository);

  final StaffRepository _repository;

  Future<StaffInviteOutcome> call(String invitationId) =>
      _repository.deleteInvitation(invitationId);
}
