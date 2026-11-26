import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/core/error/admin_error_message.dart';

import '../../di/hr_finance_dependencies.dart';
import '../../domain/models/hr_finance_models.dart';
import '../../domain/repositories/hr_finance_repository.dart';
import 'hr_finance_state.dart';

class HrFinanceCubit extends Cubit<HrFinanceState> {
  HrFinanceCubit({HrFinanceRepository? repository})
    : _repository = repository ?? HrFinanceDependencies.repository,
      super(const HrFinanceState());
  final HrFinanceRepository _repository;
  int _loadId = 0;
  bool _withEmployees = false;

  Future<void> load({bool loadEmployees = false}) async {
    _withEmployees = _withEmployees || loadEmployees;
    final id = ++_loadId;
    emit(
      state.copyWith(
        status: HrFinanceStatus.loading,
        clearError: true,
        clearBusy: true,
      ),
    );
    try {
      final values = await Future.wait<Object>([
        _repository.loadAdvances(),
        _repository.loadAdjustments(),
        _repository.loadDiscrepancies(),
        _repository.loadCashierDeductionEnabled(),
        if (_withEmployees)
          _repository.loadEmployees()
        else
          Future.value(<HrFinanceEmployee>[]),
      ]);
      if (!isClosed && id == _loadId) {
        emit(
          state.copyWith(
            status: HrFinanceStatus.ready,
            advances: values[0] as List<HrAdvance>,
            adjustments: values[1] as List<HrAdjustment>,
            discrepancies: values[2] as List<HrDiscrepancy>,
            cashierDeductionAllowed: values[3] as bool,
            employees: values[4] as List<HrFinanceEmployee>,
            clearError: true,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && id == _loadId) {
        emit(
          state.copyWith(
            status: HrFinanceStatus.failure,
            error: adminErrorMessage(error),
          ),
        );
      }
    }
  }

  Future<bool> _perform(String id, Future<void> Function() action) async {
    emit(state.copyWith(busyId: id, clearError: true));
    try {
      await action();
      await load();
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(clearBusy: true, error: adminErrorMessage(error)));
      }
      return false;
    }
  }

  Future<bool> reviewAdvance(
    HrAdvance a,
    bool approve,
    double? installment,
    String? note,
  ) => _perform(
    a.id,
    () => _repository.reviewAdvance(a.id, approve, installment, note),
  );
  Future<bool> disburseAdvance(HrAdvance a, String? note) =>
      _perform(a.id, () => _repository.disburseAdvance(a.id, note));
  Future<bool> cancelAdvance(HrAdvance a, String? note) =>
      _perform(a.id, () => _repository.cancelAdvance(a.id, note));
  Future<bool> createAdjustment(
    String staffId,
    String kind,
    double amount,
    String reason,
    String? date,
  ) => _perform(
    'create-adjustment',
    () => _repository.createAdjustment(staffId, kind, amount, reason, date),
  );
  Future<bool> reviewAdjustment(HrAdjustment a, bool approve, String? note) =>
      _perform(a.id, () => _repository.reviewAdjustment(a.id, approve, note));
  Future<bool> reverseAdjustment(HrAdjustment a, String reason) =>
      _perform(a.id, () => _repository.reverseAdjustment(a.id, reason));
  Future<bool> reviewDiscrepancy(
    HrDiscrepancy d,
    String action, {
    String? note,
    String? evidence,
    String? attributedStaffId,
    double? deductionAmount,
  }) => _perform(
    d.id,
    () => _repository.reviewDiscrepancy(
      id: d.id,
      action: action,
      note: note,
      evidence: evidence,
      attributedStaffId: attributedStaffId,
      deductionAmount: deductionAmount,
    ),
  );
}
