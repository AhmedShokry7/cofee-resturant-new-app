import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_discrepancy.dart';
import 'package:admin_app/features/hr/domain/entities/hr_finance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_schedule.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_attendance_state.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_payroll_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_advances_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_attendance_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_discrepancy_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_payroll_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_schedule_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// القرار نفسه الذي يُضغط على الهاتف يجب أن يُضغط على المكتب: هذه الانحدارات
/// كلها على `actionsOf` في جدول الشاشة العريضة، لا على البطاقة وحدها.
HrPayrollRun _run(String status) => HrPayrollRun.fromJson(<String, dynamic>{
  'run_id': 'run-1',
  'period_year': 2026,
  'period_month': 10,
  'status': status,
  'statement_count': 2,
  'total_gross': 5000,
  'total_deductions': 400,
  'total_net': 4600,
});

HrWorkSchedule _schedule(String status) =>
    HrWorkSchedule.fromJson(<String, dynamic>{
      'id': 'sch-1',
      'staff_id': 's-1',
      'staff_name': 'محمد',
      'branch_id': 'b-1',
      'branch_name_ar': 'الفرع الرئيسي',
      'date_local': '2026-10-29T00:00:00',
      'start_local': '09:00 ص',
      'end_local': '05:00 م',
      'hours': 8,
      'status': status,
    });

HrAdvance _advance(String status) => HrAdvance.fromJson(<String, dynamic>{
  'id': 'adv-1',
  'staff_id': 's-1',
  'staff_name': 'سارة',
  'amount': 1200,
  'installment_amount': 300,
  'outstanding': 900,
  'reason': 'طارئ',
  'status': status,
});

HrAdjustment _adjustment(String status, {bool claimed = false}) =>
    HrAdjustment.fromJson(<String, dynamic>{
      'id': 'adj-1',
      'staff_id': 's-1',
      'staff_name': 'سارة',
      'kind': 'addition',
      'amount': 250,
      'reason': 'بدل',
      'status': status,
      'source_type': 'manual',
      'claimed': claimed,
    });

HrDiscrepancy _discrepancy(String status) =>
    HrDiscrepancy.fromJson(<String, dynamic>{
      'id': 'd-1',
      'shift_id': 'sh-1',
      'branch_id': 'b-1',
      'branch_name_ar': 'الفرع الرئيسي',
      'drawer_cashier_id': 's-1',
      'drawer_cashier_name': ' كريم',
      'signed_variance': -80,
      'amount': 80,
      'status': status,
      'shift': <String, dynamic>{'opened_at_local': '08:00 ص'},
    });

HrAttendanceCorrection _correction(String status) =>
    HrAttendanceCorrection.fromJson(<String, dynamic>{
      'id': 'c-1',
      'staff_id': 's-1',
      'staff_name': 'محمد',
      'branch_name_ar': 'الفرع الرئيسي',
      'session_id': 'ses-1',
      'proposed_clock_in_local': '09:12 ص',
      'reason': 'نسيان بصمة',
      'status': status,
      'created_at_local': '2026-10-28 10:00 ص',
    });

List<HrBranch> get _branches => const <HrBranch>[
  HrBranch(id: 'b-1', nameAr: 'الفرع الرئيسي', nameEn: 'Main'),
];

HrListState<T> _ready<T>(List<T> items) =>
    HrListState<T>(status: HrLoadStatus.ready, items: items);

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(WidgetTester tester, Widget view) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: Directionality(textDirection: TextDirection.rtl, child: view),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  Future<void> pumpPayroll(
    WidgetTester tester, {
    required String status,
    bool canApprove = true,
    bool canPay = true,
  }) => _pump(
    tester,
    HrPayrollView(
      state: HrPayrollState(
        status: HrLoadStatus.ready,
        runs: <HrPayrollRun>[_run(status)],
      ),
      search: '',
      canManage: true,
      canApprove: canApprove,
      canPay: canPay,
      onGenerate: () {},
      onOpenRun: (_) {},
      onApprove: (_) {},
      onPay: (_) {},
      onCancel: (_) {},
      onRetry: () {},
    ),
  );

  testWidgets('a calculated run can be approved from the wide table', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await pumpPayroll(tester, status: 'calculated');

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrBtnApprove), findsWidgets);
    expect(find.text(S.hrBtnPay), findsNothing);
  });

  testWidgets('an approved run is payable, not approvable', (tester) async {
    _setViewport(tester, 1200);
    await pumpPayroll(tester, status: 'approved');

    expect(find.text(S.hrBtnPay), findsWidgets);
    expect(find.text(S.hrBtnApprove), findsNothing);
  });

  testWidgets('a payer without the approval role sees no approve button', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await pumpPayroll(tester, status: 'calculated', canApprove: false);

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrBtnApprove), findsNothing);
    // السطر يبقى مقروءًا: الصلاحية تحجب القرار لا الحقيقة.
    expect(find.text(S.hrStatusCalculated), findsWidgets);
  });

  testWidgets('a draft schedule publishes from the wide table', (tester) async {
    _setViewport(tester, 1200);
    await _pump(
      tester,
      HrScheduleView(
        state: _ready(<HrWorkSchedule>[_schedule('draft')]),
        search: '',
        canManage: true,
        branches: _branches,
        branchId: null,
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
        onBranchChanged: (_) {},
        onFromChanged: (_) {},
        onToChanged: (_) {},
        onNew: () {},
        onEdit: (_) {},
        onPublish: (_) {},
        onCancel: (_) {},
        onRetry: () {},
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrBtnPublish), findsWidgets);
  });

  testWidgets('a published schedule offers cancel, never publish again', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await _pump(
      tester,
      HrScheduleView(
        state: _ready(<HrWorkSchedule>[_schedule('published')]),
        search: '',
        canManage: true,
        branches: _branches,
        branchId: null,
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
        onBranchChanged: (_) {},
        onFromChanged: (_) {},
        onToChanged: (_) {},
        onNew: () {},
        onEdit: (_) {},
        onPublish: (_) {},
        onCancel: (_) {},
        onRetry: () {},
      ),
    );

    expect(find.text(S.hrBtnPublish), findsNothing);
    expect(find.text(S.cancel), findsWidgets);
  });

  Future<void> pumpAdvances(
    WidgetTester tester, {
    int tab = 0,
    String advanceStatus = 'pending',
    String adjustmentStatus = 'pending',
    bool claimed = false,
    bool canReview = true,
  }) => _pump(
    tester,
    HrAdvancesView(
      tab: tab,
      onTabChanged: (_) {},
      advancesState: _ready(<HrAdvance>[_advance(advanceStatus)]),
      adjustmentsState: _ready(<HrAdjustment>[
        _adjustment(adjustmentStatus, claimed: claimed),
      ]),
      search: '',
      canReview: canReview,
      canManage: true,
      people: const <HrPersonOption>[HrPersonOption('s-1', 'سارة')],
      advStatus: null,
      advStaffId: null,
      onAdvStatus: (_) {},
      onAdvStaff: (_) {},
      adjStatus: null,
      adjStaffId: null,
      adjSource: null,
      onAdjStatus: (_) {},
      onAdjStaff: (_) {},
      onAdjSource: (_) {},
      onApprove: (_) {},
      onReject: (_) {},
      onDisburse: (_) {},
      onCancel: (_) {},
      onNewAdjustment: () {},
      onAdjApprove: (_) {},
      onAdjReject: (_) {},
      onReverse: (_) {},
      onRetryAdvances: () {},
      onRetryAdjustments: () {},
    ),
  );

  testWidgets('a pending advance is decidable on the wide table', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await pumpAdvances(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrBtnApprove), findsWidgets);
    expect(find.text(S.hrActionReject), findsWidgets);
  });

  testWidgets('a disbursed advance that is still open can only be cancelled', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await pumpAdvances(tester, advanceStatus: 'disbursed');

    expect(find.text(S.hrBtnApprove), findsNothing);
    expect(find.text(S.hrBtnDisburse), findsNothing);
  });

  testWidgets('an adjustment inside a payroll snapshot is never reversible', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await pumpAdvances(
      tester,
      tab: 1,
      adjustmentStatus: 'approved',
      claimed: true,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrBtnReverse), findsNothing);
    expect(find.textContaining(S.hrAdjustmentInSnapshot), findsWidgets);
  });

  testWidgets('a pending discrepancy offers review on the wide table', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await _pump(
      tester,
      HrDiscrepancyView(
        state: _ready(<HrDiscrepancy>[_discrepancy('pending_review')]),
        search: '',
        status: null,
        branchId: null,
        branches: _branches,
        canReview: true,
        onStatusChanged: (_) {},
        onBranchChanged: (_) {},
        onReview: (_) {},
        onRetry: () {},
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrBtnReview), findsWidgets);
  });

  testWidgets('a closed discrepancy offers no review to click', (tester) async {
    _setViewport(tester, 1200);
    await _pump(
      tester,
      HrDiscrepancyView(
        state: _ready(<HrDiscrepancy>[_discrepancy('closed')]),
        search: '',
        status: null,
        branchId: null,
        branches: _branches,
        canReview: true,
        onStatusChanged: (_) {},
        onBranchChanged: (_) {},
        onReview: (_) {},
        onRetry: () {},
      ),
    );

    expect(find.text(S.hrBtnReview), findsNothing);
  });

  testWidgets('a pending correction is decidable on the corrections tab', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await _pump(
      tester,
      HrAttendanceView(
        state: HrAttendanceState(
          status: HrLoadStatus.ready,
          corrections: <HrAttendanceCorrection>[_correction('pending')],
        ),
        search: '',
        canReview: true,
        branches: _branches,
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
        branchId: null,
        correctionStatus: null,
        onBranchChanged: (_) {},
        onCorrectionStatusChanged: (_) {},
        onFromChanged: (_) {},
        onToChanged: (_) {},
        onRequestCorrection: (_) {},
        onApprove: (_) {},
        onReject: (_) {},
        onRetry: () {},
      ),
    );

    // صفحة التصحيحات مفصل داخل الشاشة نفسها، لا مسارًا آخر.
    await tester.tap(find.textContaining(S.hrSectionCorrections).first);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrBtnApprove), findsWidgets);
    expect(find.text(S.hrActionReject), findsWidgets);
  });

  testWidgets('every converged surface renders narrow without overflow', (
    tester,
  ) async {
    for (final width in <double>[360, 320]) {
      _setViewport(tester, width);
      await pumpAdvances(tester);
      expect(tester.takeException(), isNull, reason: 'advances $width');

      await pumpPayroll(tester, status: 'calculated');
      expect(tester.takeException(), isNull, reason: 'payroll $width');

      await _pump(
        tester,
        HrDiscrepancyView(
          state: _ready(<HrDiscrepancy>[_discrepancy('pending_review')]),
          search: '',
          status: null,
          branchId: null,
          branches: _branches,
          canReview: true,
          onStatusChanged: (_) {},
          onBranchChanged: (_) {},
          onReview: (_) {},
          onRetry: () {},
        ),
      );
      expect(tester.takeException(), isNull, reason: 'discrepancy $width');
    }
  });
}
