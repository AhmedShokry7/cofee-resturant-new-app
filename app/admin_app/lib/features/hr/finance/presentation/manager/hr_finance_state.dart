import '../../domain/models/hr_finance_models.dart';

enum HrFinanceStatus { initial, loading, ready, failure }

class HrFinanceState {
  const HrFinanceState({
    this.status = HrFinanceStatus.initial,
    this.advances = const [],
    this.adjustments = const [],
    this.discrepancies = const [],
    this.employees = const [],
    this.cashierDeductionAllowed = false,
    this.error,
    this.busyId,
  });
  final HrFinanceStatus status;
  final List<HrAdvance> advances;
  final List<HrAdjustment> adjustments;
  final List<HrDiscrepancy> discrepancies;
  final List<HrFinanceEmployee> employees;
  final bool cashierDeductionAllowed;
  final String? error;
  final String? busyId;

  HrFinanceState copyWith({
    HrFinanceStatus? status,
    List<HrAdvance>? advances,
    List<HrAdjustment>? adjustments,
    List<HrDiscrepancy>? discrepancies,
    List<HrFinanceEmployee>? employees,
    bool? cashierDeductionAllowed,
    String? error,
    bool clearError = false,
    String? busyId,
    bool clearBusy = false,
  }) => HrFinanceState(
    status: status ?? this.status,
    advances: advances ?? this.advances,
    adjustments: adjustments ?? this.adjustments,
    discrepancies: discrepancies ?? this.discrepancies,
    employees: employees ?? this.employees,
    cashierDeductionAllowed:
        cashierDeductionAllowed ?? this.cashierDeductionAllowed,
    error: clearError ? null : error ?? this.error,
    busyId: clearBusy ? null : busyId ?? this.busyId,
  );
}
