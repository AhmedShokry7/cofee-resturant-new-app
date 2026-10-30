import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_schedule.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_time_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_directory_cubit.dart';

/// جداول العمل في مدى مختار، مع نشر الوردية أو إلغائها.
///
/// المدى هنا سؤال للقاعدة لا مرشّح على محمَّل: `admin_hr_schedules` ترفض المدى
/// الأوسع من سقفها، فَيُرى رفضها بدل أن تُقطَع الصفوف صامتة.
class HrSchedulesCubit extends HrDirectoryCubit<HrWorkSchedule> {
  HrSchedulesCubit({HrTimeRepository? repository})
    : _repository = repository ?? HrDependencies.time;

  final HrTimeRepository _repository;

  /// أول الشهر وآخره على ساعة الجهاز؛ اليوم التجاري تحدده القاعدة بنفسها.
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime to = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  String? branchId;

  Future<void> setRange({
    required DateTime newFrom,
    required DateTime newTo,
  }) async {
    from = newFrom;
    to = newTo;
    await reload();
  }

  Future<void> setBranch(String? id) async {
    branchId = id;
    await reload();
  }

  @override
  Future<List<HrWorkSchedule>> fetch() =>
      _repository.loadSchedules(from: from, to: to, branchId: branchId);

  Future<bool> save({
    required String staffId,
    required String branch,
    required DateTime start,
    required DateTime end,
    int breakMinutes = 0,
    String status = 'draft',
    String? note,
    String? id,
  }) => submit(
    () => _repository.saveSchedule(
      staffId: staffId,
      branchId: branch,
      start: start,
      end: end,
      breakMinutes: breakMinutes,
      status: status,
      note: note,
      id: id,
    ),
  );

  /// المسودة تُنشر، والمنشورة تُلغى: الانتقال آلة حالة تحرسه 212 برمز 23514.
  Future<bool> setStatus({required String id, required String status}) =>
      submit(() => _repository.setScheduleStatus(id: id, status: status));
}
