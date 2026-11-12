import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll_preview.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_payroll_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_payroll_cubit.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// سير عمل الرواتب على الواجهة: المعاينة قراءة نقية، والإقفال خاتم مالي
/// يعيد قراءة الدورة، والدورة الفارغة لا تُعتمد من الشاشة أصلًا.
void main() {
  group('preview entity', () {
    test('parses the run block, employees, gaps and due adjustments', () {
      const json = <String, dynamic>{
        'period_year': 2026,
        'period_month': 11,
        'run': {
          'run_id': 'r1',
          'status': 'calculated',
          'calc_seq': 2,
          'statement_count': 3,
          'total_gross': 6500,
          'total_deductions': 100,
          'total_net': 6400,
          'closed_at': null,
        },
        'policy': {
          'absence_day_rate': 100,
          'late_minute_rate': 1,
          'early_minute_rate': 1,
          'unpaid_leave_day_rate': 150,
          'max_salary_deduction_percent': 5,
          'cashier_deduction_allowed': true,
        },
        'previous_month': {
          'period_year': 2026,
          'period_month': 10,
          'status': 'paid',
          'statement_count': 3,
          'total_gross': 6500,
          'total_deductions': 300,
          'total_net': 6200,
        },
        'employees': [
          {
            'staff_id': 's1',
            'staff_name': 'موظف',
            'compensation_id': 'c1',
            'basic_salary': 6000,
            'allowances_total': 500,
            'gross': 6500,
            'absence_days': 1,
            'late_minutes': 0,
            'early_minutes': 0,
            'paid_leave_days': 1,
            'unpaid_leave_days': 1,
            'attendance_deduction': 250,
            'attendance_deduction_base': 100,
            'unpaid_leave_deduction': 150,
            'additions_total': 0,
            'other_deductions': 0,
            'advance_planned': 300,
            'net_preview': 6150,
            'previous_net': 6200,
            'lines': [
              {
                'kind': 'deduction',
                'state': 'deferred',
                'label': 'مكافأة — ترحيل من 2026-10',
                'amount': 200,
              },
              {
                'kind': 'deduction',
                'state': 'cap_blocked',
                'label': 'عجز صندوق',
                'amount': 30,
              },
            ],
          },
        ],
        'adjustments_due': [
          {
            'id': 'a1',
            'staff_id': 's1',
            'staff_name': 'موظف',
            'kind': 'bonus',
            'amount': 200,
            'reason': 'مكافأة فاتت',
            'source_type': 'manual',
            'deferred': true,
            'due_date': '2026-10-01',
          },
        ],
        'missing_data': [
          {
            'staff_id': 's2',
            'staff_name': 'بلا تعويض',
            'reason': 'no compensation covering the period',
          },
        ],
      };

      final preview = HrPayrollPreview.fromJson(json);

      expect(preview.run?.calcSeq, 2);
      expect(preview.run?.status, 'calculated');
      expect(preview.previousMonth?.totalNet, 6200);
      expect(preview.policy?.unpaidLeaveDayRate, 150);
      expect(preview.employees, hasLength(1));
      final employee = preview.employees.single;
      expect(employee.netPreview, 6150);
      expect(employee.unpaidLeaveDeduction, 150);
      expect(employee.previousNet, 6200);
      expect(employee.lines.map((line) => line.state),
          containsAll(<String>['deferred', 'cap_blocked']));
      expect(preview.adjustmentsDue.single.deferred, isTrue);
      expect(preview.missingData.single.staffId, 's2');
    });

    test('an absent run block stays absent, never a zero run', () {
      const json = <String, dynamic>{
        'period_year': 2026,
        'period_month': 11,
        'employees': <dynamic>[],
        'adjustments_due': <dynamic>[],
        'missing_data': <dynamic>[],
      };
      final preview = HrPayrollPreview.fromJson(json);
      expect(preview.run, isNull);
      expect(preview.previousMonth, isNull);
      expect(preview.employees, isEmpty);
    });
  });

  group('cubit', () {
    test('loadPreview answers into its own status without touching the runs',
        () async {
      final repo = _PayrollFake();
      final cubit = HrPayrollCubit(repository: repo);
      await cubit.loadPreview(periodYear: 2026, periodMonth: 11);

      expect(cubit.state.previewStatus, HrLoadStatus.ready);
      expect(cubit.state.preview?.periodMonth, 11);
      expect(repo.lastPreviewYear, 2026);
      expect(cubit.state.status, HrLoadStatus.initial);
    });

    test('a preview refusal stays on the preview, not on the lists', () async {
      final repo = _PayrollFake();
      repo.previewFailure = const HrRefusal(
        sqlState: '42501',
        message: 'the payroll preview needs all-branch scope',
      );
      final cubit = HrPayrollCubit(repository: repo);
      await cubit.loadPreview(periodYear: 2026, periodMonth: 11);

      expect(cubit.state.previewStatus, HrLoadStatus.failure);
      expect(cubit.state.previewFailure?.isPermission, isTrue);
      expect(cubit.state.status, HrLoadStatus.initial);
    });

    test('closePeriod writes, reloads and reopens the paid run', () async {
      final repo = _PayrollFake();
      final cubit = HrPayrollCubit(repository: repo);
      await cubit.openRun('run-11');

      final ok = await cubit.closePeriod(runId: 'run-11', note: 'إقفال');

      expect(ok, isTrue);
      expect(repo.closedRunId, 'run-11');
      expect(cubit.state.run?.isClosed, isTrue);
      expect(cubit.state.run?.isCloseable, isFalse);
    });
  });
}

class _PayrollFake implements HrPayrollRepository {
  int? lastPreviewYear;
  int? lastPreviewMonth;
  String? closedRunId;
  HrRefusal? previewFailure;
  HrRefusal? writeFailure;

  final HrPayrollRun _run = HrPayrollRun(
    runId: 'run-11',
    periodYear: 2026,
    periodMonth: 11,
    status: 'paid',
    statementCount: 1,
    totalGross: 6500,
    totalDeductions: 100,
    totalNet: 6400,
    calculatedAt: null,
    approvedAt: null,
    paidAt: DateTime(2026, 11, 12),
    note: '',
    scope: 'brand',
    calcSeq: 2,
    closedAt: DateTime(2026, 11, 13),
  );

  @override
  Future<HrPayrollPreview> previewPayroll({
    required int periodYear,
    required int periodMonth,
  }) async {
    lastPreviewYear = periodYear;
    lastPreviewMonth = periodMonth;
    final failure = previewFailure;
    if (failure != null) throw failure;
    return HrPayrollPreview(
      periodYear: periodYear,
      periodMonth: periodMonth,
      employees: const [],
      adjustmentsDue: const [],
      missingData: const [],
    );
  }

  @override
  Future<HrReceipt> closePeriod({required String runId, String? note}) async {
    final failure = writeFailure;
    if (failure != null) throw failure;
    closedRunId = runId;
    return const HrReceipt(
      id: 'run-11',
      status: 'paid',
    );
  }

  @override
  Future<List<HrPayrollRun>> loadPayrollRuns({int limit = 24}) async =>
      <HrPayrollRun>[_run];

  @override
  Future<HrPayrollRun> loadPayrollRun(String runId) async => _run;

  @override
  Future<HrPayrollStatement> loadStatement(String statementId) async =>
      throw UnimplementedError();

  @override
  Future<List<HrPayrollStatement>> loadMyPayslips() async =>
      const <HrPayrollStatement>[];

  @override
  Future<HrReceipt> generatePayroll({
    required int periodYear,
    required int periodMonth,
    String? note,
  }) async =>
      const HrReceipt(id: '', status: '');

  @override
  Future<HrReceipt> approvePayroll({required String runId, String? note}) async =>
      const HrReceipt(id: '', status: '');

  @override
  Future<HrReceipt> payPayroll({required String runId, String? note}) async =>
      const HrReceipt(id: '', status: '');

  @override
  Future<HrReceipt> cancelPayrollRun({required String runId, String? note}) async =>
      const HrReceipt(id: '', status: '');

  @override
  Future<HrReceipt> payrollCorrection({
    required String statementId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
  }) async =>
      const HrReceipt(id: '', status: '');

  @override
  Future<HrReceipt> setCompensation({
    required String staffId,
    required double basicSalary,
    double housingAllowance = 0,
    double transportAllowance = 0,
    double otherAllowance = 0,
    DateTime? effectiveFrom,
    String? note,
  }) async =>
      const HrReceipt(id: '', status: '');
}

// Silence the unused-import lint for S in this test when no string is asserted.
// ignore_for_file: unused_element
class _StringsProbe {
  String get probe => S.hrPayrollPreview;
}
