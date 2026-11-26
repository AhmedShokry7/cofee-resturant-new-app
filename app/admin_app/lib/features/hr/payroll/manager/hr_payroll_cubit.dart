import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/core/error/admin_error_message.dart';

import '../data/supabase_hr_payroll_repository.dart';
import '../domain/hr_payroll_repository.dart';
import 'hr_payroll_state.dart';

class HrPayrollCubit extends Cubit<HrPayrollState> {
  HrPayrollCubit({HrPayrollRepository? repository})
    : _repository = repository ?? SupabaseHrPayrollRepository(),
      super(_initial());
  final HrPayrollRepository _repository;

  static HrPayrollState _initial() {
    final now = DateTime.now();
    return HrPayrollState(
      selectedYear: now.month == 1 ? now.year - 1 : now.year,
      selectedMonth: now.month == 1 ? 12 : now.month - 1,
    );
  }

  void selectYear(int year) =>
      emit(state.copyWith(selectedYear: year, clearPreview: true));
  void selectMonth(int month) =>
      emit(state.copyWith(selectedMonth: month, clearPreview: true));
  void clearPreview() => emit(state.copyWith(clearPreview: true));

  Future<void> load() async {
    emit(state.copyWith(status: HrPayrollStatus.loading, clearError: true));
    try {
      final runs = await _repository.loadRuns();
      if (!isClosed) {
        emit(state.copyWith(status: HrPayrollStatus.ready, runs: runs));
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: HrPayrollStatus.failure,
            error: adminErrorMessage(error),
          ),
        );
      }
    }
  }

  Future<void> loadRun(String id) async {
    emit(state.copyWith(actionBusy: true, clearError: true));
    try {
      final detail = await _repository.loadRun(id);
      if (!isClosed) emit(state.copyWith(detail: detail, actionBusy: false));
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(actionBusy: false, error: adminErrorMessage(error)),
        );
      }
    }
  }

  Future<void> loadPreview() async {
    emit(state.copyWith(actionBusy: true, clearError: true));
    try {
      final preview = await _repository.preview(
        state.selectedYear,
        state.selectedMonth,
      );
      if (!isClosed) emit(state.copyWith(preview: preview, actionBusy: false));
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(actionBusy: false, error: adminErrorMessage(error)),
        );
      }
    }
  }

  Future<bool> _act(Future<void> Function() action) async {
    emit(state.copyWith(actionBusy: true, clearError: true));
    try {
      await action();
      final runs = await _repository.loadRuns();
      if (!isClosed) {
        emit(
          state.copyWith(
            status: HrPayrollStatus.ready,
            runs: runs,
            actionBusy: false,
            clearDetail: true,
            clearPreview: true,
          ),
        );
      }
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(actionBusy: false, error: adminErrorMessage(error)),
        );
      }
      return false;
    }
  }

  Future<bool> generate(String? note) => _act(
    () => _repository.generate(state.selectedYear, state.selectedMonth, note),
  );
  Future<bool> approve(String id, String? note) =>
      _act(() => _repository.approve(id, note));
  Future<bool> markPaid(String id, String? reference) =>
      _act(() => _repository.markPaid(id, reference));
  Future<bool> cancel(String id, String reason) =>
      _act(() => _repository.cancel(id, reason));
  Future<bool> closePeriod(String id, String? note) =>
      _act(() => _repository.closePeriod(id, note));

  Future<bool> correction({
    required String statementId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
  }) => _act(
    () => _repository.correction(
      statementId: statementId,
      kind: kind,
      amount: amount,
      reason: reason,
      effectiveDate: effectiveDate,
    ),
  );
}
