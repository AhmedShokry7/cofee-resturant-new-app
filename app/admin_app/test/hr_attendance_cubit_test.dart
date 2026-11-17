import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/features/hr/attendance/data/hr_attendance_repository.dart';
import 'package:admin_app/features/hr/attendance/manager/hr_attendance_cubit.dart';

class _FakeAttendanceRepository implements HrAttendanceRepository {
  String? lastBranch;
  String? reviewedId;
  bool? approved;

  @override
  Future<List<Map<String, dynamic>>> loadBranches() async => [
    {'id': 'branch-1', 'name_en': 'North'},
  ];

  @override
  Future<List<Map<String, dynamic>>> loadAttendance({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async {
    lastBranch = branchId;
    return [
      {'id': 'session-1', 'staff_name': 'Sam'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> loadCorrections() async => [
    {'id': 'correction-1', 'status': 'pending'},
  ];

  @override
  Future<void> reviewCorrection({
    required String correctionId,
    required bool approve,
    required String note,
  }) async {
    reviewedId = correctionId;
    approved = approve;
  }
}

void main() {
  test(
    'loads attendance and correction inbox within the selected scope',
    () async {
      final repository = _FakeAttendanceRepository();
      final cubit = HrAttendanceCubit(repository: repository, canReview: true);
      await cubit.load(branchId: 'branch-1');

      expect(cubit.state.status, HrAttendanceStatus.ready);
      expect(repository.lastBranch, 'branch-1');
      expect(cubit.state.sessions, hasLength(1));
      expect(cubit.state.corrections, hasLength(1));
      expect(cubit.state.branches.single['id'], 'branch-1');
      await cubit.close();
    },
  );

  test('refuses invalid or overlong server date ranges', () async {
    final repository = _FakeAttendanceRepository();
    final cubit = HrAttendanceCubit(repository: repository);
    final start = DateTime(2026, 1, 1);
    await cubit.load(from: start, to: start.add(const Duration(days: 93)));

    expect(cubit.state.error, 'hr_date_range_invalid');
    expect(repository.lastBranch, isNull);
    await cubit.close();
  });

  test('reviews a correction through the review contract', () async {
    final repository = _FakeAttendanceRepository();
    final cubit = HrAttendanceCubit(repository: repository, canReview: true);
    await cubit.review(
      correctionId: 'correction-1',
      approve: false,
      note: 'Missing evidence',
    );

    expect(repository.reviewedId, 'correction-1');
    expect(repository.approved, isFalse);
    expect(cubit.state.reviewing, isFalse);
    await cubit.close();
  });
}
