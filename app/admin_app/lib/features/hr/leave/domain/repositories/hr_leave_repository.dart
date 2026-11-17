import '../models/hr_leave_models.dart';

abstract interface class HrLeaveRepository {
  Future<List<HrLeaveType>> loadTypes();
  Future<List<HrLeaveRequest>> loadRequests({String? status});
  Future<void> reviewRequest({
    required String requestId,
    required bool approve,
    String? note,
  });
  Future<void> setBalance({
    required String staffId,
    required String leaveTypeId,
    required int year,
    required double entitledDays,
  });
  Future<void> saveType(HrLeaveType type, {bool create = false});
}
