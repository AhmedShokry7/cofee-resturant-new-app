import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/core/error/admin_error_message.dart';

import '../../di/hr_leave_dependencies.dart';
import '../../domain/models/hr_leave_models.dart';
import '../../domain/repositories/hr_leave_repository.dart';
import 'hr_leave_state.dart';

class HrLeaveCubit extends Cubit<HrLeaveState> {
  HrLeaveCubit({HrLeaveRepository? repository})
    : _repository = repository ?? HrLeaveDependencies.repository,
      super(const HrLeaveState());
  final HrLeaveRepository _repository;
  int _loadSequence = 0;

  Future<void> load({String? status}) async {
    final request = ++_loadSequence;
    emit(
      state.copyWith(
        status: HrLeaveStatus.loading,
        clearError: true,
        clearBusy: true,
        isSaving: false,
      ),
    );
    try {
      final values = await Future.wait<Object>([
        _repository.loadTypes(),
        _repository.loadRequests(status: status),
      ]);
      if (!isClosed && request == _loadSequence) {
        emit(
          state.copyWith(
            status: HrLeaveStatus.ready,
            types: values[0] as List<HrLeaveType>,
            requests: values[1] as List<HrLeaveRequest>,
            filterStatus: status,
            clearFilter: status == null,
            clearError: true,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && request == _loadSequence) {
        emit(
          state.copyWith(
            status: HrLeaveStatus.failure,
            errorMessage: adminErrorMessage(error),
          ),
        );
      }
    }
  }

  Future<void> filter(String? status) => load(status: status);

  Future<bool> review(
    HrLeaveRequest request, {
    required bool approve,
    required String note,
  }) async {
    emit(state.copyWith(busyRequestId: request.id, clearError: true));
    try {
      await _repository.reviewRequest(
        requestId: request.id,
        approve: approve,
        note: note.trim().isEmpty ? null : note.trim(),
      );
      await load(status: state.filterStatus);
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            clearBusy: true,
            errorMessage: adminErrorMessage(error),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> setBalance({
    required HrLeaveRequest request,
    required int year,
    required double entitledDays,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repository.setBalance(
        staffId: request.staffId,
        leaveTypeId: request.leaveTypeId,
        year: year,
        entitledDays: entitledDays,
      );
      await load(status: state.filterStatus);
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage: adminErrorMessage(error),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> saveType(HrLeaveType type, {bool create = false}) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repository.saveType(type, create: create);
      await load(status: state.filterStatus);
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage: adminErrorMessage(error),
          ),
        );
      }
      return false;
    }
  }
}
