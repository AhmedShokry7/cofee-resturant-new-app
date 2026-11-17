import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/features/hr/data/repositories/supabase_hr_employee_repository.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employment_draft.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_employee_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employee_state.dart';

class HrEmployeeCubit extends Cubit<HrEmployeeState> {
  HrEmployeeCubit({HrEmployeeRepository? repository})
    : _repository = repository ?? SupabaseHrEmployeeRepository(),
      super(const HrEmployeeState());

  final HrEmployeeRepository _repository;

  Future<void> load(String staffId) async {
    emit(state.copyWith(status: HrEmployeeStatus.loading, clearError: true));
    try {
      final employee = await _repository.loadEmployee(staffId);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: HrEmployeeStatus.ready,
          employee: employee,
          clearError: true,
          saved: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: HrEmployeeStatus.failure,
          errorMessage: adminErrorMessage(error),
        ),
      );
    }
  }

  Future<bool> saveEmployment(HrEmploymentDraft employment) async {
    final employee = state.employee;
    if (employee == null || state.status == HrEmployeeStatus.saving) {
      return false;
    }
    emit(
      state.copyWith(
        status: HrEmployeeStatus.saving,
        clearError: true,
        saved: false,
      ),
    );
    try {
      final saved = await _repository.saveEmployment(
        staffId: employee.staffId,
        employment: employment,
      );
      if (isClosed) return false;
      emit(
        state.copyWith(
          status: HrEmployeeStatus.ready,
          employee: employee.withEmployment(saved),
          clearError: true,
          saved: true,
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          status: HrEmployeeStatus.ready,
          errorMessage: adminErrorMessage(error),
        ),
      );
      return false;
    }
  }
}
