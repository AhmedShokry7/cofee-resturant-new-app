import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_leave.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_leave_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_money_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_payroll_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_people_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_time_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_my_day_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// منطق شاشة «يومي»: بصمتي، إجازتي، قسائمي، وسلفة أطلبها.
///
/// كل ما هنا ملك المستخدم نفسه، فلا صلاحية تتعدى هويته؛ والكتابة ترفضها
/// القاعدة في SQL إن لم يكن لها وجه، فيُعرض رفضها حرفيًا.
class HrMyDayCubit extends Cubit<HrMyDayState> {
  HrMyDayCubit({
    HrTimeRepository? time,
    HrLeaveRepository? leave,
    HrPayrollRepository? payroll,
    HrMoneyRepository? money,
    HrPeopleRepository? people,
  }) : _time = time ?? HrDependencies.time,
       _leave = leave ?? HrDependencies.leave,
       _payroll = payroll ?? HrDependencies.payroll,
       _money = money ?? HrDependencies.money,
       _people = people ?? HrDependencies.people,
       super(const HrMyDayState());

  final HrTimeRepository _time;
  final HrLeaveRepository _leave;
  final HrPayrollRepository _payroll;
  final HrMoneyRepository _money;
  final HrPeopleRepository _people;

  Future<void> load() async {
    emit(state.copyWith(status: HrLoadStatus.loading, clearFailure: true));
    try {
      final reference = await _people.loadReference();
      emit(
        state.copyWith(
          status: HrLoadStatus.ready,
          reference: reference,
          clearFailure: true,
        ),
      );
      await _reload();
    } catch (error) {
      emit(
        state.copyWith(
          status: HrLoadStatus.failure,
          failure: hrRefusalOf(error),
        ),
      );
    }
  }

  Future<void> clockIn(String branchId) =>
      _stamp(() => _time.clockIn(branchId: branchId));

  Future<void> clockOut() => _stamp(_time.clockOut);

  Future<void> breakStart() => _stamp(_time.breakStart);

  Future<void> breakEnd() => _stamp(_time.breakEnd);

  Future<void> requestLeave({
    required String leaveTypeId,
    required DateTime startsOn,
    required DateTime endsOn,
    String? reason,
    String? supportingDocument,
  }) => _write(() async {
    await _leave.requestLeave(
      leaveTypeId: leaveTypeId,
      startsOn: startsOn,
      endsOn: endsOn,
      reason: reason,
      supportingDocument: supportingDocument,
    );
  });

  Future<void> cancelLeave(String requestId) =>
      _write(() => _leave.cancelRequest(requestId: requestId));

  Future<void> requestAdvance({
    required double amount,
    required String reason,
    double? installment,
  }) => _write(
    () => _money.requestAdvance(
      amount: amount,
      reason: reason,
      installment: installment,
    ),
  );

  /// البصمة تُرجع جلستها، فتُحدَّث البطاقة بها فورًا قبل إعادة قراءة السجل.
  Future<void> _stamp(Future<HrAttendanceSession> Function() send) => _write(
    send,
    onResult: (session) => emit(state.copyWith(lastSession: session)),
  );

  /// مسار الكتابة الواحد: قفل الأزرار، ثم نجاحٌ يُعيد قراءة يومي من القاعدة،
  /// أو رفضٌ يبقى نصّه على الشاشة كما رفعته 212.
  Future<void> _write<T>(
    Future<T> Function() send, {
    void Function(T result)? onResult,
  }) async {
    emit(state.copyWith(writing: HrWriteStatus.sending, clearFailure: true));
    HrRefusal? failure;
    try {
      final result = await send();
      onResult?.call(result);
      await _reload();
    } catch (error) {
      failure = hrRefusalOf(error);
    }
    emit(
      state.copyWith(
        writing: HrWriteStatus.done,
        failure: failure,
        clearFailure: failure == null,
      ),
    );
  }

  /// إعادة قراءة ما يعرضه اليوم: الجلسة المفتوحة، وقسيمة آخر شهر صدرت له،
  /// والطلبات التي ما زالت باسمي.
  Future<void> _reload() async {
    final mine = state.reference?.myStaffId;
    emit(
      state.copyWith(
        attendance: await _time.loadMyAttendance(),
        payslips: await _payroll.loadMyPayslips(),
        leaves: mine == null
            ? const <HrLeaveRequest>[]
            : await _leave.loadRequests(staffId: mine),
      ),
    );
  }
}
