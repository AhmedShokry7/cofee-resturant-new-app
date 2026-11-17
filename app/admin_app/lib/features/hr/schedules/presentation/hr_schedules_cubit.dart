import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/core/error/admin_error_message.dart';

import '../data/supabase_hr_schedule_repository.dart';
import '../domain/hr_schedule.dart';
import '../domain/hr_schedule_repository.dart';

enum HrSchedulesStatus { initial, loading, ready, failure }

class HrSchedulesState {
  const HrSchedulesState({
    this.status = HrSchedulesStatus.initial,
    this.schedules = const [],
    this.branches = const [],
    this.employees = const [],
    this.error,
    this.branchId,
  });
  final HrSchedulesStatus status;
  final List<HrSchedule> schedules;
  final List<HrScheduleBranch> branches;
  final List<HrScheduleEmployee> employees;
  final String? error;
  final String? branchId;

  HrSchedulesState copyWith({
    HrSchedulesStatus? status,
    List<HrSchedule>? schedules,
    List<HrScheduleBranch>? branches,
    List<HrScheduleEmployee>? employees,
    String? error,
    bool clearError = false,
    String? branchId,
    bool clearBranch = false,
  }) => HrSchedulesState(
    status: status ?? this.status,
    schedules: schedules ?? this.schedules,
    branches: branches ?? this.branches,
    employees: employees ?? this.employees,
    error: clearError ? null : error ?? this.error,
    branchId: clearBranch ? null : branchId ?? this.branchId,
  );
}

class HrSchedulesCubit extends Cubit<HrSchedulesState> {
  HrSchedulesCubit({HrScheduleRepository? repository})
    : _repository = repository ?? SupabaseHrScheduleRepository(),
      super(const HrSchedulesState());
  final HrScheduleRepository _repository;
  int _loadToken = 0;

  Future<void> load({
    required DateTime from,
    required DateTime to,
    required bool canReadEmployees,
    String? branchId,
  }) async {
    final token = ++_loadToken;
    emit(state.copyWith(status: HrSchedulesStatus.loading, clearError: true));
    try {
      final reference = await _repository.loadReference(
        canReadEmployees: canReadEmployees,
      );
      final schedules = await _repository.loadSchedules(
        from: from,
        to: to,
        branchId: branchId,
      );
      if (isClosed || token != _loadToken) return;
      emit(
        state.copyWith(
          status: HrSchedulesStatus.ready,
          branches: reference.$1,
          employees: reference.$2,
          schedules: schedules,
          branchId: branchId,
          clearBranch: branchId == null,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed || token != _loadToken) return;
      emit(
        state.copyWith(
          status: HrSchedulesStatus.failure,
          error: adminErrorMessage(error),
        ),
      );
    }
  }

  Future<void> save({
    required String staffId,
    required String branchId,
    required DateTime start,
    required DateTime end,
    required int breakMinutes,
    required String status,
    required String note,
    String? id,
    required DateTime from,
    required DateTime to,
    required bool canReadEmployees,
  }) async {
    try {
      await _repository.saveSchedule(
        staffId: staffId,
        branchId: branchId,
        start: start,
        end: end,
        breakMinutes: breakMinutes,
        status: status,
        note: note,
        id: id,
      );
      await load(
        from: from,
        to: to,
        canReadEmployees: canReadEmployees,
        branchId: state.branchId,
      );
    } catch (error) {
      emit(state.copyWith(error: adminErrorMessage(error)));
    }
  }

  Future<void> setStatus({
    required String id,
    required String status,
    required DateTime from,
    required DateTime to,
    required bool canReadEmployees,
  }) async {
    try {
      await _repository.setStatus(id, status);
      await load(
        from: from,
        to: to,
        canReadEmployees: canReadEmployees,
        branchId: state.branchId,
      );
    } catch (error) {
      emit(state.copyWith(error: adminErrorMessage(error)));
    }
  }
}
