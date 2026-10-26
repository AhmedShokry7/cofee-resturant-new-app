import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// منح صلاحية لموظف أو سحبها.
class SetStaffPermissionUseCase {
  const SetStaffPermissionUseCase(this._repository);

  final StaffRepository _repository;

  Future<void> call(String staffId, String permissionCode, bool granted) =>
      _repository.setStaffPermission(staffId, permissionCode, granted);
}
