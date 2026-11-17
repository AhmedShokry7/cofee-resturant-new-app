import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/hr/payroll/domain/hr_payroll_models.dart';
import 'package:admin_app/features/hr/payroll/domain/hr_payroll_repository.dart';
import 'package:admin_app/features/hr/payroll/manager/hr_payroll_cubit.dart';
import 'package:admin_app/features/hr/payroll/presentation/hr_payroll_page.dart';

class _FakePayrollRepository implements HrPayrollRepository {
  @override
  Future<List<HrPayrollRun>> loadRuns() async => [
    HrPayrollRun.fromJson({
      'run_id': 'run-1',
      'period_year': 2025,
      'period_month': 3,
      'status': 'calculated',
      'statement_count': 3,
      'total_gross': 12000,
      'total_deductions': 500,
      'total_net': 11500,
    }),
  ];

  @override
  Future<HrJson> loadRun(String id) async => {'run_id': id};

  @override
  Future<HrPayrollPreview> preview(int year, int month) async =>
      HrPayrollPreview.fromJson({
        'period_year': year,
        'period_month': month,
        'employees': [
          {'gross': 1000, 'net_preview': 950, 'attendance_deduction': 50},
        ],
        'missing_data': [],
        'adjustments_due': [],
      });

  @override
  Future<void> generate(int year, int month, String? note) async {}
  @override
  Future<void> approve(String runId, String? note) async {}
  @override
  Future<void> markPaid(String runId, String? reference) async {}
  @override
  Future<void> cancel(String runId, String reason) async {}
  @override
  Future<void> closePeriod(String runId, String? note) async {}
  @override
  Future<void> correction({
    required String statementId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
  }) async {}
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('shows company-wide monthly runs for payroll readers', (
    tester,
  ) async {
    final cubit = HrPayrollCubit(repository: _FakePayrollRepository());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HrPayrollPage(
            cubit: cubit,
            canRead: true,
            canPrepare: false,
            canApprove: false,
            canPay: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payroll'), findsOneWidget);
    expect(find.text('March 2025'), findsOneWidget);
    expect(find.textContaining('11500.00 SAR'), findsOneWidget);
    expect(find.text('Preview run'), findsNothing);
    await cubit.close();
  });

  test('payroll run and preview models read aggregate values', () {
    final run = HrPayrollRun.fromJson({
      'total_net': 123.45,
      'statement_count': 2,
    });
    final preview = HrPayrollPreview.fromJson({
      'employees': [
        {'net_preview': 50},
        {'net_preview': 75.25},
      ],
    });
    expect(run.net, 123.45);
    expect(run.count, 2);
    expect(preview.total('net_preview'), 125.25);
  });
}
