import '../../domain/models/hr_leave_models.dart';

enum HrLeaveStatus { initial, loading, ready, failure }

class HrLeaveState {
  const HrLeaveState({
    this.status = HrLeaveStatus.initial,
    this.requests = const [],
    this.types = const [],
    this.filterStatus,
    this.errorMessage,
    this.busyRequestId,
    this.isSaving = false,
  });

  final HrLeaveStatus status;
  final List<HrLeaveRequest> requests;
  final List<HrLeaveType> types;
  final String? filterStatus;
  final String? errorMessage;
  final String? busyRequestId;
  final bool isSaving;

  HrLeaveState copyWith({
    HrLeaveStatus? status,
    List<HrLeaveRequest>? requests,
    List<HrLeaveType>? types,
    String? filterStatus,
    bool clearFilter = false,
    String? errorMessage,
    bool clearError = false,
    String? busyRequestId,
    bool clearBusy = false,
    bool? isSaving,
  }) => HrLeaveState(
    status: status ?? this.status,
    requests: requests ?? this.requests,
    types: types ?? this.types,
    filterStatus: clearFilter ? null : filterStatus ?? this.filterStatus,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    busyRequestId: clearBusy ? null : busyRequestId ?? this.busyRequestId,
    isSaving: isSaving ?? this.isSaving,
  );
}
