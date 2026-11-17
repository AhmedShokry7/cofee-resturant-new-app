import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/core/error/admin_error_message.dart';

import '../data/supabase_hr_compensation_repository.dart';
import '../domain/hr_compensation_repository.dart';

enum HrCompensationStatus { initial, loading, ready, failure }

class HrCompensationState {
  const HrCompensationState({
    this.status = HrCompensationStatus.initial,
    this.employees = const [],
    this.selectedStaffId,
    this.compensation,
    this.error,
    this.saving = false,
  });

  final HrCompensationStatus status;
  final List<HrCompensationEmployee> employees;
  final String? selectedStaffId;
  final Map<String, dynamic>? compensation;
  final String? error;
  final bool saving;

  HrCompensationState copyWith({
    HrCompensationStatus? status,
    List<HrCompensationEmployee>? employees,
    String? selectedStaffId,
    bool clearSelected = false,
    Map<String, dynamic>? compensation,
    bool clearCompensation = false,
    String? error,
    bool clearError = false,
    bool? saving,
  }) => HrCompensationState(
    status: status ?? this.status,
    employees: employees ?? this.employees,
    selectedStaffId: clearSelected
        ? null
        : selectedStaffId ?? this.selectedStaffId,
    compensation: clearCompensation ? null : compensation ?? this.compensation,
    error: clearError ? null : error ?? this.error,
    saving: saving ?? this.saving,
  );
}

class HrCompensationCubit extends Cubit<HrCompensationState> {
  HrCompensationCubit({HrCompensationRepository? repository})
    : _repository = repository ?? SupabaseHrCompensationRepository(),
      super(const HrCompensationState());

  final HrCompensationRepository _repository;
  int _selectionToken = 0;

  Future<void> load() async {
    emit(
      state.copyWith(status: HrCompensationStatus.loading, clearError: true),
    );
    try {
      final employees = await _repository.loadEmployees();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: HrCompensationStatus.ready,
          employees: employees,
          clearError: true,
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: HrCompensationStatus.failure,
            error: adminErrorMessage(error),
          ),
        );
      }
    }
  }

  Future<void> selectEmployee(String staffId) async {
    final token = ++_selectionToken;
    emit(
      state.copyWith(
        status: HrCompensationStatus.loading,
        selectedStaffId: staffId,
        clearCompensation: true,
        clearError: true,
      ),
    );
    try {
      final compensation = await _repository.loadEmployeeCompensation(staffId);
      if (isClosed || token != _selectionToken) return;
      if (compensation == null) {
        throw StateError(
          'Compensation data is not available for this account.',
        );
      }
      emit(
        state.copyWith(
          status: HrCompensationStatus.ready,
          compensation: compensation,
          clearError: true,
        ),
      );
    } catch (error) {
      if (!isClosed && token == _selectionToken) {
        emit(
          state.copyWith(
            status: HrCompensationStatus.failure,
            error: adminErrorMessage(error),
          ),
        );
      }
    }
  }

  Future<bool> addCompensation({
    required double basicSalary,
    required double housingAllowance,
    required double transportAllowance,
    required double otherAllowance,
    required DateTime effectiveFrom,
    required String note,
  }) async {
    final staffId = state.selectedStaffId;
    if (staffId == null) return false;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.addCompensation(
        staffId: staffId,
        basicSalary: basicSalary,
        housingAllowance: housingAllowance,
        transportAllowance: transportAllowance,
        otherAllowance: otherAllowance,
        effectiveFrom: effectiveFrom,
        note: note,
      );
      final compensation = await _repository.loadEmployeeCompensation(staffId);
      if (isClosed) return false;
      emit(
        state.copyWith(
          status: HrCompensationStatus.ready,
          compensation: compensation,
          saving: false,
          clearError: true,
        ),
      );
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(saving: false, error: adminErrorMessage(error)));
      }
      return false;
    }
  }
}
