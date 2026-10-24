import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/staff/data/repositories/admin_staff_repository.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_state.dart';

class AdminStaffCubit extends Cubit<AdminStaffState> {
  AdminStaffCubit({AdminStaffRepository? repository})
    : _repository = repository ?? AdminStaffRepository(),
      super(const AdminStaffState());

  final AdminStaffRepository _repository;

  AdminStaffRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminStaffStatus.loading, clearError: true));
    try {
      final staff = await _repository.loadStaff();
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

  Future<List<Map<String, dynamic>>> loadPermissions() =>
      _repository.loadPermissions();

  Future<void> setStaffPermission(String staffId, String code, bool granted) =>
      _repository.setStaffPermission(staffId, code, granted);
}
