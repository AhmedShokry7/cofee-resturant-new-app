import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// قراءة كل الموظفين.
class LoadStaffUseCase {
  const LoadStaffUseCase(this._repository);

  final StaffRepository _repository;

  Future<List<AdminStaffMember>> call() => _repository.loadStaff();
}
