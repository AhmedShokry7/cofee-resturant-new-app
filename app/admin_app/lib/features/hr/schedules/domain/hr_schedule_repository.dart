import 'hr_schedule.dart';

abstract interface class HrScheduleRepository {
  Future<(List<HrScheduleBranch>, List<HrScheduleEmployee>)> loadReference({
    required bool canReadEmployees,
  });
  Future<List<HrSchedule>> loadSchedules({
    required DateTime from,
    required DateTime to,
    String? branchId,
  });
  Future<void> saveSchedule({
    required String staffId,
    required String branchId,
    required DateTime start,
    required DateTime end,
    required int breakMinutes,
    required String status,
    required String note,
    String? id,
  });
  Future<void> setStatus(String id, String status);
}
