import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_time_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_attempt.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_attendance_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// الحضور كما تراه الإدارة، وتصحيحاته التي تُراجع.
///
/// الجلسة لا تُحرَّر محليًا أبدًا: التصحيح طلبٌ عند صاحبي القرار، والموافقة
/// تكتب الوقت في السجلّ وتترك الطلب أثرًا قابلًا للتدقيق.
class HrAttendanceCubit extends Cubit<HrAttendanceState> {
  HrAttendanceCubit({HrTimeRepository? repository})
    : _repository = repository ?? HrDependencies.time,
      super(const HrAttendanceState());

  final HrTimeRepository _repository;

  DateTime from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime to = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  String? branchId;
  String? staffId;
  String? correctionStatus;

  Future<void> setRange({
    required DateTime newFrom,
    required DateTime newTo,
  }) async {
    from = newFrom;
    to = newTo;
    await reload();
  }

  Future<void> setBranch(String? value) async {
    branchId = value;
    await reload();
  }

  Future<void> setCorrectionStatus(String? value) async {
    correctionStatus = value;
    await reload();
  }

  Future<void> reload() async {
    emit(state.copyWith(status: HrLoadStatus.loading, clearFailure: true));
    try {
      final rows = await _repository.loadAttendance(
        from: from,
        to: to,
        branchId: branchId,
        staffId: staffId,
      );
      final corrections = await _repository.loadCorrections(
        status: correctionStatus,
      );
      emit(
        state.copyWith(
          status: HrLoadStatus.ready,
          rows: rows,
          corrections: corrections,
          clearFailure: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: HrLoadStatus.failure,
          failure: hrRefusalOf(error),
        ),
      );
    }
  }

  Future<bool> requestCorrection({
    required String staff,
    String? sessionId,
    DateTime? clockInAt,
    DateTime? clockOutAt,
    required String reason,
  }) => _write(
    () => _repository.requestCorrection(
      staffId: staff,
      sessionId: sessionId,
      clockInAt: clockInAt,
      clockOutAt: clockOutAt,
      reason: reason,
    ),
  );

  Future<bool> review({
    required String correctionId,
    required bool approve,
    String? note,
  }) => _write(
    () => _repository.reviewCorrection(
      correctionId: correctionId,
      approve: approve,
      note: note,
    ),
  );

  Future<bool> _write(Future<Object?> Function() send) async {
    emit(state.copyWith(writing: HrWriteStatus.sending, clearFailure: true));
    final failure = await hrAttempt(send);
    emit(
      state.copyWith(
        writing: HrWriteStatus.done,
        failure: failure,
        clearFailure: failure == null,
      ),
    );
    if (failure == null) await reload();
    return failure == null;
  }
}
