import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/staff/di/staff_dependencies.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';
import 'package:admin_app/features/staff/domain/usecases/load_permissions.dart';
import 'package:admin_app/features/staff/domain/usecases/load_staff.dart';
import 'package:admin_app/features/staff/domain/usecases/set_staff_permission.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_state.dart';

class AdminStaffCubit extends Cubit<AdminStaffState> {
  AdminStaffCubit({StaffRepository? repository})
    : this._withUseCases(repository ?? StaffDependencies.repository);

  AdminStaffCubit._withUseCases(StaffRepository repository)
    : _loadStaff = LoadStaffUseCase(repository),
      _loadPermissions = LoadPermissionsUseCase(repository),
      _setStaffPermission = SetStaffPermissionUseCase(repository),
      super(const AdminStaffState());

  final LoadStaffUseCase _loadStaff;
  final LoadPermissionsUseCase _loadPermissions;
  final SetStaffPermissionUseCase _setStaffPermission;

  Future<void> load() async {
    emit(state.copyWith(status: AdminStaffStatus.loading, clearError: true));
    try {
      final staff = await _loadStaff();
      emit(
        state.copyWith(
          status: AdminStaffStatus.ready,
          staff: staff,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminStaffStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> loadPermissions() => _loadPermissions();

  Future<void> setStaffPermission(String staffId, String code, bool granted) =>
      _setStaffPermission(staffId, code, granted);
}
