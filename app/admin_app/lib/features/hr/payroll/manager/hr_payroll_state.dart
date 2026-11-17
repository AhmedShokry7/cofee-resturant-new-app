import '../domain/hr_payroll_models.dart';

enum HrPayrollStatus { initial, loading, ready, failure }

class HrPayrollState {
  const HrPayrollState({
    this.status = HrPayrollStatus.initial,
    this.runs = const [],
    this.detail,
    this.preview,
    this.error,
    this.actionBusy = false,
    this.selectedYear = 0,
    this.selectedMonth = 0,
  });
  final HrPayrollStatus status;
  final List<HrPayrollRun> runs;
  final HrJson? detail;
  final HrPayrollPreview? preview;
  final String? error;
  final bool actionBusy;
  final int selectedYear;
  final int selectedMonth;

  HrPayrollState copyWith({
    HrPayrollStatus? status,
    List<HrPayrollRun>? runs,
    HrJson? detail,
    bool clearDetail = false,
    HrPayrollPreview? preview,
    bool clearPreview = false,
    String? error,
    bool clearError = false,
    bool? actionBusy,
    int? selectedYear,
    int? selectedMonth,
  }) => HrPayrollState(
    status: status ?? this.status,
    runs: runs ?? this.runs,
    detail: clearDetail ? null : detail ?? this.detail,
    preview: clearPreview ? null : preview ?? this.preview,
    error: clearError ? null : error ?? this.error,
    actionBusy: actionBusy ?? this.actionBusy,
    selectedYear: selectedYear ?? this.selectedYear,
    selectedMonth: selectedMonth ?? this.selectedMonth,
  );
}
