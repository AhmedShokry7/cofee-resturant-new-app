import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_dashboard.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_dashboard_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// اللوحة تُقرأ من سؤال واحد، فما لم ترجع به القاعدة لا يجوز أن يُصنَع صفرًا.
HrDashboard _board({
  bool withAttendance = false,
  bool withFinance = false,
  bool withPending = false,
  bool withRun = false,
  bool withPayslip = false,
}) => HrDashboard.fromJson(<String, dynamic>{
  'today': '2026-10-29',
  'time_zone': 'Asia/Riyadh',
  'permissions': <String, dynamic>{'hr': true},
  'headcount': <String, dynamic>{
    'total': 4,
    'active': 3,
    'probation': 1,
    'on_leave': 0,
    'terminated': 0,
  },
  'today_attendance': withAttendance
      ? <String, dynamic>{'scheduled': 3, 'present': 2, 'open': 1, 'late': 0}
      : null,
  'pending': withPending
      ? <String, dynamic>{
          'leave_requests': 2,
          'attendance_corrections': 0,
          'advances': 1,
          'adjustments': 0,
          'discrepancies': 0,
        }
      : <String, dynamic>{},
  'finance': withFinance
      ? <String, dynamic>{
          'open_discrepancies': 1,
          'open_discrepancy_amount': 80,
          'advances_outstanding': 900,
        }
      : null,
  'payroll': <String, dynamic>{
    'period_year': 2026,
    'period_month': 10,
    'run': withRun
        ? <String, dynamic>{
            'run_id': 'run-1',
            'status': 'calculated',
            'total_net': 4600,
            'statement_count': 2,
          }
        : null,
  },
  'me': <String, dynamic>{
    'staff_id': 's-1',
    'worked_minutes_today': 0,
    'pending_leave': 0,
    'open_advance': 0,
    'latest_payslip': withPayslip
        ? <String, dynamic>{
            'statement_id': 'st-1',
            'period_year': 2026,
            'period_month': 9,
            'net': 4200,
            'currency_code': 'SAR',
          }
        : null,
  },
});

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  HrDashboardState state, {
  List<HrBranch> branches = const <HrBranch>[
    HrBranch(id: 'b-1', nameAr: 'الفرع الرئيسي', nameEn: 'Main'),
    HrBranch(id: 'b-2', nameAr: 'الواجهة البحرية', nameEn: 'Waterfront'),
  ],
  HrRefusal? branchesFailure,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: HrDashboardView(
            state: state,
            branches: branches,
            branchesFailure: branchesFailure,
            onBranchChanged: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('a section the rule did not answer is unavailable, not zero', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(
      tester,
      HrDashboardState(status: HrLoadStatus.ready, dashboard: _board()),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrUnavailable), findsWidgets);
    // عدّات الفريق وحدها وصلت، فنالت أرقامها؛ والباب المغلقة لم تُصفَّر.
    expect(find.text(localizeDigits('4')), findsWidgets);
  });

  testWidgets('a real zero prints its own digit', (tester) async {
    _setViewport(tester, 1400);
    await _pump(
      tester,
      HrDashboardState(
        status: HrLoadStatus.ready,
        dashboard: _board(
          withAttendance: true,
          withFinance: true,
          withPending: true,
          withRun: true,
          withPayslip: true,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrUnavailable), findsNothing);
    // «صفر» جاء من القاعدة لا من غيابها: حضورٌ صفر في باب مفتوح.
    expect(find.text(localizeDigits('0')), findsWidgets);
    expect(find.text(S.hrRunNone), findsNothing);
  });

  testWidgets('a month with no run says so instead of a zero payroll', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(
      tester,
      HrDashboardState(
        status: HrLoadStatus.ready,
        dashboard: _board(withRun: false),
      ),
    );

    expect(find.text(S.hrRunNone), findsOneWidget);
    expect(find.text(S.hrNoPayslipsYet), findsOneWidget);
  });

  testWidgets('a door the reader cannot count is never offered', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(
      tester,
      HrDashboardState(
        status: HrLoadStatus.ready,
        dashboard: _board(withPending: true),
      ),
    );

    // الأبواب الخمسة جاءت بأرقامها، فباب التسويات صفرٌ معلن لا كلمة غيب.
    expect(find.text(S.hrPendingLeaves), findsOneWidget);
    expect(find.text(S.hrPendingDiscrepancies), findsOneWidget);
  });

  testWidgets('a read that failed with nothing on the board is a failure', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(
      tester,
      HrDashboardState(
        status: HrLoadStatus.failure,
        failure: const HrRefusal(
          sqlState: '42501',
          message: 'missing permission: hr.employee.read',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining(S.hrMissingPermission), findsWidgets);
    expect(find.text(S.hrHeadcount), findsNothing);
  });

  testWidgets('a branch list that failed says why instead of hiding the gate', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(
      tester,
      HrDashboardState(
        status: HrLoadStatus.ready,
        dashboard: _board(withAttendance: true),
      ),
      branches: const <HrBranch>[],
      branchesFailure: const HrRefusal(
        sqlState: '',
        message: 'branches could not be read',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('branches could not be read'), findsWidgets);
  });

  testWidgets('one branch in scope offers no filter to click', (tester) async {
    _setViewport(tester, 1400);
    await _pump(
      tester,
      HrDashboardState(
        status: HrLoadStatus.ready,
        dashboard: _board(withAttendance: true),
      ),
      branches: const <HrBranch>[
        HrBranch(id: 'b-1', nameAr: 'الفرع الرئيسي', nameEn: 'Main'),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrFilterAllBranches), findsNothing);
  });

  testWidgets('the board scrolls narrow without overflow', (tester) async {
    for (final width in <double>[360, 320]) {
      _setViewport(tester, width);
      await _pump(
        tester,
        HrDashboardState(
          status: HrLoadStatus.ready,
          dashboard: _board(
            withAttendance: true,
            withFinance: true,
            withPending: true,
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
