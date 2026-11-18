import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/features/hr/schedules/domain/hr_schedule.dart';
import 'package:admin_app/features/hr/schedules/domain/hr_schedule_repository.dart';
import 'package:admin_app/features/hr/schedules/presentation/hr_schedules_cubit.dart';
import 'package:admin_app/features/hr/schedules/presentation/hr_schedules_page.dart';
import 'package:admin_app/core/locale/app_strings.dart';

class _FakeScheduleRepository implements HrScheduleRepository {
  @override
  Future<(List<HrScheduleBranch>, List<HrScheduleEmployee>)> loadReference({
    required bool canReadEmployees,
  }) async => (
    [const HrScheduleBranch('branch-1', 'الفرع', 'Branch')],
    canReadEmployees
        ? <HrScheduleEmployee>[const HrScheduleEmployee('staff-1', 'Employee')]
        : <HrScheduleEmployee>[],
  );

  @override
  Future<List<HrSchedule>> loadSchedules({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async => const [];

  @override
  Future<void> saveSchedule({
    required String staffId,
    required String branchId,
    required DateTime start,
    required DateTime end,
    required int breakMinutes,
    required String status,
    required String note,
    String? id,
  }) async {}

  @override
  Future<void> setStatus(String id, String status) async {}
}

void main() {
  testWidgets('schedule assignment requires employee read permission', (
    tester,
  ) async {
    final cubit = HrSchedulesCubit(repository: _FakeScheduleRepository());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HrSchedulesPage(
            canManage: true,
            canReadEmployees: false,
            cubit: cubit,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(S.hrScheduleEmployeePickerRequired), findsOneWidget);
    expect(find.text(S.hrCreateSchedule), findsNothing);
    await cubit.close();
  });

  testWidgets(
    'schedule manager can start a draft when employee data is in scope',
    (tester) async {
      final cubit = HrSchedulesCubit(repository: _FakeScheduleRepository());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HrSchedulesPage(
              canManage: true,
              canReadEmployees: true,
              cubit: cubit,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.hrCreateSchedule), findsOneWidget);
      await cubit.close();
    },
  );
}
