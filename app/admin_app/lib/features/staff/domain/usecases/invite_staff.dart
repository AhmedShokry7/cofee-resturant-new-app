import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// إنشاء دعوة موظف جديد بالبريد والدور والفرع.
class InviteStaffUseCase {
  const InviteStaffUseCase(this._repository);

  final StaffRepository _repository;

  Future<StaffInviteResult> call({
    required String email,
    required String fullName,
    required String roleCode,
    String? branchId,
  }) => _repository.inviteStaff(
    email: email,
    fullName: fullName,
    roleCode: roleCode,
    branchId: branchId,
  );
}
