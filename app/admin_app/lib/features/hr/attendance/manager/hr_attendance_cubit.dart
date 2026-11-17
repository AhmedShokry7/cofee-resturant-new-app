import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/admin_error_message.dart';
import '../data/hr_attendance_repository.dart';

enum HrAttendanceStatus { initial, loading, ready, failure }

class HrAttendanceState {
  const HrAttendanceState({
    this.status = HrAttendanceStatus.initial,
    this.from,
    this.to,
    this.branchId,
    this.branches = const [],
    this.sessions = const [],
    this.corrections = const [],
    this.error,
    this.reviewing = false,
  });

  final HrAttendanceStatus status;
  final DateTime? from;
  final DateTime? to;
  final String? branchId;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> corrections;
  final String? error;
  final bool reviewing;

  HrAttendanceState copyWith({
    HrAttendanceStatus? status,
    DateTime? from,
    DateTime? to,
    String? branchId,
    bool clearBranch = false,
    List<Map<String, dynamic>>? branches,
    List<Map<String, dynamic>>? sessions,
    List<Map<String, dynamic>>? corrections,
    String? error,
    bool clearError = false,
    bool? reviewing,
  }) => HrAttendanceState(
    status: status ?? this.status,
    from: from ?? this.from,
    to: to ?? this.to,
    branchId: clearBranch ? null : branchId ?? this.branchId,
    branches: branches ?? this.branches,
    sessions: sessions ?? this.sessions,
    corrections: corrections ?? this.corrections,
    error: clearError ? null : error ?? this.error,
    reviewing: reviewing ?? this.reviewing,
  );
}

class HrAttendanceCubit extends Cubit<HrAttendanceState> {
  HrAttendanceCubit({
    HrAttendanceRepository? repository,
    this.canReview = false,
  }) : _repository = repository ?? SupabaseHrAttendanceRepository(),
       super(
         HrAttendanceState(
           from: DateTime.now().subtract(const Duration(days: 6)),
           to: DateTime.now(),
         ),
       );

  final HrAttendanceRepository _repository;
  final bool canReview;
  int _request = 0;

  Future<void> load({
    DateTime? from,
    DateTime? to,
    String? branchId,
    bool clearBranch = false,
  }) async {
    final start = from ?? state.from!;
    final end = to ?? state.to!;
    if (end.isBefore(start) || end.difference(start).inDays > 92) {
      emit(state.copyWith(error: 'hr_date_range_invalid'));
      return;
    }
    final request = ++_request;
    emit(
      state.copyWith(
        status: HrAttendanceStatus.loading,
        from: start,
        to: end,
        branchId: branchId,
        clearBranch: clearBranch,
        clearError: true,
      ),
    );
    try {
      final branches = await _repository.loadBranches();
      final sessions = await _repository.loadAttendance(
        from: start,
        to: end,
        branchId: clearBranch ? null : branchId ?? state.branchId,
      );
      final corrections = canReview
          ? await _repository.loadCorrections()
          : const <Map<String, dynamic>>[];
      if (!isClosed && request == _request) {
        emit(
          state.copyWith(
            status: HrAttendanceStatus.ready,
            branches: branches,
            sessions: sessions,
            corrections: corrections,
            clearError: true,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && request == _request) {
        emit(
          state.copyWith(
            status: HrAttendanceStatus.failure,
            error: adminErrorMessage(error),
          ),
        );
      }
    }
  }

  Future<void> setBranch(String? id) =>
      load(branchId: id, clearBranch: id == null);

  Future<void> review({
    required String correctionId,
    required bool approve,
    required String note,
  }) async {
    emit(state.copyWith(reviewing: true, clearError: true));
    try {
      await _repository.reviewCorrection(
        correctionId: correctionId,
        approve: approve,
        note: note,
      );
      await load();
      if (!isClosed) emit(state.copyWith(reviewing: false));
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(reviewing: false, error: adminErrorMessage(error)));
      }
    }
  }
}
