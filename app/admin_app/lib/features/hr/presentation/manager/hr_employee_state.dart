import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';

enum HrEmployeeStatus { initial, loading, ready, saving, failure }

class HrEmployeeState {
  const HrEmployeeState({
    this.status = HrEmployeeStatus.initial,
    this.employee,
    this.errorMessage,
    this.saved = false,
  });

  final HrEmployeeStatus status;
  final HrEmployeeFile? employee;
  final String? errorMessage;
  final bool saved;

  HrEmployeeState copyWith({
    HrEmployeeStatus? status,
    HrEmployeeFile? employee,
    String? errorMessage,
    bool clearError = false,
    bool? saved,
  }) => HrEmployeeState(
    status: status ?? this.status,
    employee: employee ?? this.employee,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    saved: saved ?? this.saved,
  );
}
