import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_leave.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/domain/entities/hr_schedule.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_leave_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_payroll_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_people_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_time_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_attendance_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_my_day_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_payroll_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_schedules_cubit.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// بصمة وجدول ورواتب: الرفض يبقى رفضًا، والقراءة تعود من القاعدة لا من الشاشة.
void main() {
  group('attendance', () {
    test('a refused range keeps the shifts already read', () async {
      final time = _TimeFake();
      final cubit = HrAttendanceCubit(repository: time);
      await cubit.reload();
      expect(cubit.state.rows, hasLength(1));

      time.failure = HrRefusal(
        sqlState: '22023',
        message: 'attendance range is limited to 92 days',
      );
      await cubit.setRange(
        newFrom: DateTime(2020, 1, 1),
        newTo: DateTime(2026, 1, 1),
      );

      expect(cubit.state.status, HrLoadStatus.failure);
      expect(cubit.state.rows, hasLength(1));
      expect(cubit.state.failure?.isValidation, isTrue);
    });

    test(
      'a pending correction count is read, not counted from the screen',
      () async {
        final time = _TimeFake();
        final cubit = HrAttendanceCubit(repository: time);
        await cubit.reload();

        expect(cubit.state.pendingCorrections, 1);
        expect(cubit.state.corrections.single.isPending, isTrue);
      },
    );

    test(
      'self-approval of a correction is refused with the rule’s own text',
      () async {
        final time = _TimeFake();
        final cubit = HrAttendanceCubit(repository: time);
        await cubit.reload();
        time.failure = HrRefusal(
          sqlState: '42501',
          message: 'you cannot approve your own attendance correction',
        );

        final done = await cubit.review(correctionId: 'cor-1', approve: true);

        expect(done, isFalse);
        expect(cubit.state.failure?.isPermission, isTrue);
        expect(cubit.state.corrections.single.status, 'pending');
        expect(cubit.state.writing, HrWriteStatus.done);
      },
    );
  });

  group('schedules', () {
    test(
      'an overlapping shift is refused and nothing is appended locally',
      () async {
        final time = _TimeFake();
        final cubit = HrSchedulesCubit(repository: time);
        await cubit.reload();
        final loadsBefore = time.scheduleLoads;
        time.failure = HrRefusal(
          sqlState: '23505',
          message: 'overlapping work schedule',
        );

        final done = await cubit.save(
          staffId: 's-1',
          branch: 'b-1',
          start: DateTime(2026, 10, 29, 9),
          end: DateTime(2026, 10, 29, 17),
        );

        expect(done, isFalse);
        expect(cubit.state.receipt, isNull);
        expect(cubit.state.items, hasLength(1));
        expect(cubit.state.items.single.status, 'published');
        // الرفض لا يُعاد قراءة: ما كُتب لم يُكتب، فلا شيء تغيّر ليُعاد جلبه.
        expect(time.scheduleLoads, loadsBefore);
      },
    );

    test(
      'a saved schedule is re-read because the rule returns the snapshot',
      () async {
        final time = _TimeFake();
        final cubit = HrSchedulesCubit(repository: time);
        await cubit.reload();
        final loadsBefore = time.scheduleLoads;

        final done = await cubit.save(
          staffId: 's-2',
          branch: 'b-1',
          start: DateTime(2026, 10, 30, 9),
          end: DateTime(2026, 10, 30, 17),
        );

        expect(done, isTrue);
        expect(time.scheduleLoads, loadsBefore + 1);
        expect(cubit.state.items, hasLength(2));
      },
    );
  });

  group('payroll', () {
    test(
      'generating an approved period is refused and the run stays as read',
      () async {
        final payroll = _PayrollFake();
        final cubit = HrPayrollCubit(repository: payroll);
        await cubit.reload();
        payroll.failure = HrRefusal(
          sqlState: '23514',
          message: 'this payroll period is already approved',
        );

        final done = await cubit.generate(periodYear: 2026, periodMonth: 10);

        expect(done, isFalse);
        expect(cubit.state.runs.single.status, 'calculated');
        expect(cubit.state.receipt, isNull);
        expect(
          hrRefusalMessage(cubit.state.failure!),
          S.hrPeriodAlreadyApproved,
        );
      },
    );

    test(
      'approving re-reads the open run instead of retouching its picture',
      () async {
        final payroll = _PayrollFake();
        final cubit = HrPayrollCubit(repository: payroll);
        await cubit.reload();
        await cubit.openRun('run-1');
        expect(cubit.state.run?.isCalculated, isTrue);

        final done = await cubit.approve(runId: 'run-1', note: 'اعتماد الشهر');

        expect(done, isTrue);
        expect(payroll.runLoads, greaterThan(1));
        expect(cubit.state.run?.isApproved, isTrue);
        expect(cubit.state.run?.statements.single.runStatus, 'approved');
      },
    );

    test('a refused run read is a failure, never an empty month', () async {
      final payroll = _PayrollFake()
        ..failure = HrRefusal(
          sqlState: '42501',
          message: 'missing permission: hr.payroll.read',
        );
      final cubit = HrPayrollCubit(repository: payroll);

      await cubit.reload();

      expect(cubit.state.status, HrLoadStatus.failure);
      expect(cubit.state.runs, isEmpty);
      expect(cubit.state.failure?.isPermission, isTrue);
    });
  });

  group('my day', () {
    test('a second clock-in is refused and no fake session appears', () async {
      final time = _TimeFake();
      final cubit = HrMyDayCubit(
        time: time,
        people: _PeopleFake(),
        payroll: _PayrollFake(),
        leave: _LeaveFake(),
      );
      await cubit.load();
      expect(cubit.state.canClock, isTrue);

      time.failure = HrRefusal(
        sqlState: '23505',
        message: 'already clocked in',
      );
      await cubit.clockIn('b-1');

      expect(cubit.state.failure?.isDuplicate, isTrue);
      expect(hrRefusalMessage(cubit.state.failure!), S.hrAlreadyClockedIn);
      expect(cubit.state.openSession?.isReal, isTrue);
    });

    test(
      'a refused reference leaves the clock with nothing to offer',
      () async {
        final cubit = HrMyDayCubit(
          people: _PeopleFake()
            ..failure = HrRefusal(
              sqlState: '42501',
              message: 'staff member out of scope',
            ),
        );

        await cubit.load();

        expect(cubit.state.status, HrLoadStatus.failure);
        expect(cubit.state.reference, isNull);
        expect(cubit.state.canClock, isFalse);
      },
    );
  });
}

class _TimeFake implements HrTimeRepository {
  List<HrAttendanceRow> rows = <HrAttendanceRow>[
    HrAttendanceRow.fromJson(<String, dynamic>{
      'id': 'ses-1',
      'staff_id': 's-1',
      'staff_name': 'سارة',
      'branch_id': 'b-1',
      'branch_name_ar': 'الروضة',
      'date_local': '2026-10-01',
      'clock_in_local': '2026-10-01 08:55',
      'clock_out_local': '2026-10-01 17:05',
      'worked_minutes': 480,
      'late_minutes': 0,
      'is_open': false,
    }),
  ];
  List<HrAttendanceCorrection> corrections = <HrAttendanceCorrection>[
    HrAttendanceCorrection.fromJson(<String, dynamic>{
      'id': 'cor-1',
      'staff_id': 's-1',
      'staff_name': 'سارة',
      'status': 'pending',
      'proposed_clock_in_local': '2026-10-02 09:00',
    }),
  ];
  List<HrWorkSchedule> schedules = <HrWorkSchedule>[
    HrWorkSchedule.fromJson(<String, dynamic>{
      'id': 'sch-1',
      'staff_id': 's-1',
      'staff_name': 'سارة',
      'branch_id': 'b-1',
      'branch_name_ar': 'الروضة',
      'date_local': '2026-10-29',
      'start_local': '2026-10-29 09:00',
      'end_local': '2026-10-29 17:00',
      'break_minutes': 60,
      'hours': 7,
      'status': 'published',
    }),
  ];

  Object? failure;
  int scheduleLoads = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  void _guard() {
    if (failure != null) throw failure!;
  }

  @override
  Future<List<HrAttendanceRow>> loadAttendance({
    required DateTime from,
    required DateTime to,
    String? branchId,
    String? staffId,
  }) async {
    _guard();
    return rows;
  }

  @override
  Future<List<HrAttendanceCorrection>> loadCorrections({String? status}) async {
    _guard();
    return corrections;
  }

  @override
  Future<HrAttendanceSession?> reviewCorrection({
    required String correctionId,
    required bool approve,
    String? note,
  }) async {
    _guard();
    if (approve) {
      corrections = <HrAttendanceCorrection>[
        for (final row in corrections)
          if (row.id == correctionId)
            HrAttendanceCorrection.fromJson(<String, dynamic>{
              'id': row.id,
              'staff_id': row.staffId,
              'staff_name': row.staffName,
              'status': 'approved',
            })
          else
            row,
      ];
    }
    return null;
  }

  @override
  Future<List<HrWorkSchedule>> loadSchedules({
    required DateTime from,
    required DateTime to,
    String? branchId,
    String? staffId,
  }) async {
    scheduleLoads += 1;
    _guard();
    return schedules;
  }

  @override
  Future<HrWorkSchedule> saveSchedule({
    required String staffId,
    required String branchId,
    required DateTime start,
    required DateTime end,
    int breakMinutes = 0,
    String status = 'draft',
    String? note,
    String? id,
  }) async {
    _guard();
    final saved = HrWorkSchedule.fromJson(<String, dynamic>{
      'id': id ?? 'sch-2',
      'staff_id': staffId,
      'branch_id': branchId,
      'date_local': '2026-10-30',
      'status': status,
    });
    schedules = <HrWorkSchedule>[...schedules, saved];
    return saved;
  }

  @override
  Future<HrAttendanceSession> clockIn({
    required String branchId,
    String? note,
  }) async {
    _guard();
    return HrAttendanceSession.fromJson(<String, dynamic>{
      'id': 'ses-new',
      'branch_id': branchId,
      'is_open': true,
    });
  }

  @override
  Future<HrMyAttendance> loadMyAttendance({
    DateTime? from,
    DateTime? to,
  }) async {
    _guard();
    return HrMyAttendance.fromJson(<String, dynamic>{
      'staff_id': 's-1',
      'open_session': <String, dynamic>{'id': 'ses-1', 'is_open': true},
      'sessions': const <Object>[],
      'metrics': const <String, dynamic>{},
    });
  }
}

class _PeopleFake implements HrPeopleRepository {
  Object? failure;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<HrReference> loadReference() async {
    if (failure != null) throw failure!;
    return HrReference.fromJson(<String, dynamic>{
      'branches': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'b-1', 'name_ar': 'الروضة'},
      ],
      'my_staff_id': 's-1',
    });
  }
}

/// طلبات إجازة الموظف نفسه: تكفي فارغة مقروءة، فالاختبار على البصمة لا عليها.
class _LeaveFake implements HrLeaveRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<List<HrLeaveRequest>> loadRequests({
    String? status,
    String? staffId,
  }) async => const <HrLeaveRequest>[];
}

class _PayrollFake implements HrPayrollRepository {
  List<HrPayrollRun> runs = <HrPayrollRun>[
    HrPayrollRun.fromJson(<String, dynamic>{
      'run_id': 'run-1',
      'period_year': 2026,
      'period_month': 10,
      'status': 'calculated',
      'statement_count': 1,
      'total_gross': 5200,
      'total_deductions': 300,
      'total_net': 4900,
    }),
  ];

  Object? failure;
  int runLoads = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  void _guard() {
    if (failure != null) throw failure!;
  }

  @override
  Future<List<HrPayrollRun>> loadPayrollRuns({int limit = 24}) async {
    runLoads += 1;
    _guard();
    return runs;
  }

  @override
  Future<HrPayrollRun> loadPayrollRun(String runId) async {
    _guard();
    return runs.firstWhere((run) => run.runId == runId);
  }

  @override
  Future<List<HrPayrollStatement>> loadMyPayslips() async {
    _guard();
    return const <HrPayrollStatement>[];
  }

  @override
  Future<HrReceipt> generatePayroll({
    required int periodYear,
    required int periodMonth,
    String? note,
  }) async {
    _guard();
    return HrReceipt.fromJson(<String, dynamic>{'run_id': 'run-2'});
  }

  /// الاعتماد يغيّر الدورة وقسيماتها في القاعدة، فلا تُصلَح الصورة محليًا.
  @override
  Future<HrReceipt> approvePayroll({
    required String runId,
    String? note,
  }) async {
    _guard();
    runs = <HrPayrollRun>[
      for (final run in runs)
        if (run.runId == runId)
          HrPayrollRun.fromJson(<String, dynamic>{
            'run_id': runId,
            'period_year': run.periodYear,
            'period_month': run.periodMonth,
            'status': 'approved',
            'statement_count': 1,
            'total_gross': run.totalGross,
            'total_deductions': run.totalDeductions,
            'total_net': run.totalNet,
            'statements': <Map<String, dynamic>>[
              <String, dynamic>{
                'statement_id': 'st-1',
                'run_status': 'approved',
              },
            ],
          })
        else
          run,
    ];
    return HrReceipt.fromJson(<String, dynamic>{
      'run_id': runId,
      'status': 'approved',
    });
  }
}
