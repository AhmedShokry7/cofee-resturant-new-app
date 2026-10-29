import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// تعديل اسم الموظف أو بريده أو حالته.
class UpdateStaffUseCase {
  const UpdateStaffUseCase(this._repository);

  final StaffRepository _repository;

  Future<StaffEditOutcome> call({
    required String staffId,
    String? fullName,
    String? email,
    String? status,
  }) => _repository.updateStaff(
    staffId: staffId,
    fullName: fullName,
    email: email,
    status: status,
  );
}
