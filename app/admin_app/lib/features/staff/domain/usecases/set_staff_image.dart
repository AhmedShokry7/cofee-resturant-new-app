import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// تسجيل مسار صورة موظف أو إفراغه.
class SetStaffImageUseCase {
  const SetStaffImageUseCase(this._repository);

  final StaffRepository _repository;

  Future<StaffEditOutcome> call(String staffId, String? path) =>
      _repository.setStaffImage(staffId, path);
}
