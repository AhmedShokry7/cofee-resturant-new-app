import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// قراءة الدعوات المعلَّقة مع حالتها التي تقيّمها القاعدة لحظة القراءة.
class LoadInvitationsUseCase {
  const LoadInvitationsUseCase(this._repository);

  final StaffRepository _repository;

  Future<List<AdminStaffInvitation>> call() => _repository.loadInvitations();
}
