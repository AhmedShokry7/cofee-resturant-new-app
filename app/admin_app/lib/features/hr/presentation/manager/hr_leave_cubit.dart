import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_leave.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_leave_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_directory_cubit.dart';

/// طلبات الإجازة: مراجعة الطلب وضبط رصيد سنة لموظف.
///
/// الرصيد لا يُلمس إلا عند الاعتماد، فالرفض إجابة لا نصف تنفيذ؛ ولهذا يبقى
/// الضبط كتابةً منفصلة يراها السجلّ لا حسابًا محليًا في الشاشة.
class HrLeaveCubit extends HrDirectoryCubit<HrLeaveRequest> {
  HrLeaveCubit({HrLeaveRepository? repository})
    : _repository = repository ?? HrDependencies.leave;

  final HrLeaveRepository _repository;

  String? status;
  String? staffId;

  Future<void> setStatus(String? value) async {
    status = value;
    await reload();
  }

  Future<void> setStaff(String? value) async {
    staffId = value;
    await reload();
  }

  @override
  Future<List<HrLeaveRequest>> fetch() =>
      _repository.loadRequests(status: status, staffId: staffId);

  Future<bool> review({
    required String requestId,
    required bool approve,
    String? note,
  }) => submit(
    () => _repository.reviewRequest(
      requestId: requestId,
      approve: approve,
      note: note,
    ),
  );

  Future<bool> setBalance({
    required String staffId,
    required String leaveTypeId,
    required int year,
    required double entitledDays,
  }) => submit(
    () => _repository.setBalance(
      staffId: staffId,
      leaveTypeId: leaveTypeId,
      year: year,
      entitledDays: entitledDays,
    ),
  );
}
