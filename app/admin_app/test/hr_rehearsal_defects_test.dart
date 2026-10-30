import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_discrepancy.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employees_state.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_my_day_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_clock_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_discrepancy_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_employees_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_leave_types_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_my_day_body.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_my_day_metrics_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// انحدارات التدريب الحيّ للوحة HR (F1–F16): كل اختبار هنا يكتب سلوكًا كان
/// الشاشة تقول عكسه على هاتف المدير، فيُقرأ بلا قاعدة ولا متصفح.

const List<HrBranch> _branches = <HrBranch>[
  HrBranch(id: 'b-1', nameAr: 'الفرع الرئيسي', nameEn: 'Main'),
];

HrAttendanceSession _session({required bool open}) => HrAttendanceSession(
  id: 'ses-1',
  staffId: 's-1',
  branchId: 'b-1',
  branchName: 'الفرع الرئيسي',
  clockIn: DateTime.utc(2026, 10, 29, 8),
  clockOut: open ? null : DateTime.utc(2026, 10, 29, 16),
  clockInLocal: '08:00 ص',
  clockOutLocal: open ? '' : '04:00 م',
  breakStartedAt: null,
  breakEndedAt: null,
  isOpen: open,
  isOnBreak: false,
  workedMinutes: 480,
  note: '',
  clockOutNote: '',
);

HrEmployee _employee() => const HrEmployee(
  staffId: 's-1',
  userId: 'u-1',
  fullName: 'سارة',
  email: 's@x.com',
  accountStatus: 'active',
  // رقم وعقد بلا قيمة: هذا بالضبط ما كان يترك خلية صامتة على الهاتف.
  employment: HrEmployment(employeeNumber: '', department: ''),
);

HrDiscrepancy _discrepancy() => HrDiscrepancy.fromJson(<String, dynamic>{
  'id': 'd-1',
  'shift_id': 'sh-1',
  'branch_id': 'b-1',
  'branch_name_ar': 'الفرع الرئيسي',
  'drawer_cashier_id': 's-1',
  'drawer_cashier_name': 'كريم',
  'signed_variance': -80,
  'amount': 80,
  'status': 'pending_review',
  'shift': <String, dynamic>{'opened_at_local': '08:00 ص'},
});

HrLeaveType _leaveType({
  required bool paid,
  required bool tracks,
  required bool document,
}) => HrLeaveType(
  id: 'lt-1',
  code: 'annual',
  nameAr: 'إجازة سنوية',
  nameEn: 'Annual leave',
  requiresDocument: document,
  isPaid: paid,
  tracksBalance: tracks,
);

HrListState<T> _ready<T>(List<T> items) =>
    HrListState<T>(status: HrLoadStatus.ready, items: items);

void _setViewport(
  WidgetTester tester, {
  double width = 531,
  double height = 553,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(WidgetTester tester, Widget view) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: Directionality(
          textDirection: AppLocale.instance.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: view,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('F1 — بطاقة البصمة تقرأ حالة الجلسة', () {
    testWidgets('جلسة مقفلة لا تعرض زرّ انصراف', (tester) async {
      await _pump(
        tester,
        HrClockCard(
          branches: _branches,
          session: _session(open: false),
          canClock: true,
          busy: false,
          onClockIn: (_) {},
          onClockOut: () {},
          onBreakStart: () {},
          onBreakEnd: () {},
        ),
      );
      expect(find.text(S.hrBtnClockOut), findsNothing);
      expect(find.text(S.hrBtnClockIn), findsOneWidget);
    });

    testWidgets('جلسة مفتوحة تعرض انصراف وحده', (tester) async {
      await _pump(
        tester,
        HrClockCard(
          branches: _branches,
          session: _session(open: true),
          canClock: true,
          busy: false,
          onClockIn: (_) {},
          onClockOut: () {},
          onBreakStart: () {},
          onBreakEnd: () {},
        ),
      );
      expect(find.text(S.hrBtnClockOut), findsOneWidget);
      expect(find.text(S.hrBtnClockIn), findsNothing);
    });
  });

  group('F3 — صفر المدة كبقية قيم العمود', () {
    test('الصفر «0د» لا «د 0»', () {
      expect(hrDuration(0), localizeDigits('0${S.hrMinutesShort}'));
      expect(hrDuration(2), localizeDigits('2${S.hrMinutesShort}'));
    });
  });

  group('F2 — أرقام البصمة تقول من أين جاءت', () {
    testWidgets('شريط يومي يقول مصدر الحضور والمدة', (tester) async {
      await _pump(
        tester,
        const HrMyDayMetricsStrip(
          metrics: HrAttendanceMetrics(
            scheduledShifts: 0,
            scheduledMinutes: 0,
            absenceDays: 0,
            lateMinutes: 0,
            earlyMinutes: 0,
            workedMinutes: 2,
            presentShifts: 0,
          ),
        ),
      );
      // صفرٌ من جدولٍ لم يُنشر مع مدةٍ من بصمة: الجملة هي الفرق، لا لون.
      expect(find.text(S.hrMetricsSources), findsOneWidget);
    });
  });

  group('F5/F6 — بطاقة الموظف تُفتح، والقيمة غير المكتوبة تُقرأ', () {
    testWidgets('لمسة البطاقة الضيقة تفتح الملف', (tester) async {
      _setViewport(tester);
      String? opened;
      await _pump(
        tester,
        HrEmployeesView(
          state: HrEmployeesState(
            status: HrLoadStatus.ready,
            employees: <HrEmployee>[_employee()],
          ),
          reference: null,
          search: '',
          status: null,
          branchId: null,
          department: null,
          onStatusChanged: (_) {},
          onBranchChanged: (_) {},
          onDepartmentChanged: (_) {},
          onOpenFile: (staffId) => opened = staffId,
          onRetry: () {},
        ),
      );
      await tester.tap(find.text('سارة').first);
      await tester.pump();
      expect(opened, 's-1');
    });

    testWidgets('الرقم والقسم الفارغان يقرآن كما يُقرأ التاريخ الغائب', (
      tester,
    ) async {
      _setViewport(tester);
      await _pump(
        tester,
        HrEmployeesView(
          state: HrEmployeesState(
            status: HrLoadStatus.ready,
            employees: <HrEmployee>[_employee()],
          ),
          reference: null,
          search: '',
          status: null,
          branchId: null,
          department: null,
          onStatusChanged: (_) {},
          onBranchChanged: (_) {},
          onDepartmentChanged: (_) {},
          onOpenFile: (_) {},
          onRetry: () {},
        ),
      );
      expect(find.text(S.hrNoValue), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('F8 — مرشّح الموظف من المرجع لا من سطور الصفحة', () {
    testWidgets('الدليل الذي لم يُقرأ يُقال، لا «لا ملفّ في النطاق»', (
      tester,
    ) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => hrEmployeeField(
            context,
            people: null,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text(S.hrEmployeesUnread), findsOneWidget);
    });

    testWidgets('الدليل المقروء بلا ملفّ يُقال كذلك', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => hrEmployeeField(
            context,
            people: const <HrPersonOption>[],
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text(S.hrEmptyEmployees), findsOneWidget);
    });

    test('أول مرشَّح مقروء هو الافتتاحي، وبلا مرشَّح لا موظف مُختَرع', () {
      expect(
        hrFirstPersonId(const <HrPersonOption>[HrPersonOption('s-9', 'سارة')]),
        's-9',
      );
      expect(hrFirstPersonId(null), isNull);
      expect(hrFirstPersonId(const <HrPersonOption>[]), isNull);
    });
  });

  group('F9/F10 — الحوار يتمرّر ورفضه يبقى مقروءًا', () {
    testWidgets('حوار أطول من الشاشة لا ينصبّ ولا يفقد شريط الرفض', (
      tester,
    ) async {
      _setViewport(tester, height: 320);
      await _pump(
        tester,
        HrFormDialog(
          title: S.hrScheduleTitle,
          saveLabel: S.save,
          error: 'اختر الموظف أولًا',
          onSave: () {},
          children: <Widget>[
            for (var index = 0; index < 12; index++)
              TextField(controller: TextEditingController()),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      // الرفض فوق الحقول: تحتها كان خارج الشاشة فيقول «لم يحدث شيء».
      expect(find.text('اختر الموظف أولًا'), findsOneWidget);
      await tester.dragUntilVisible(
        find.byKey(const Key('hr-form-save')),
        find.byType(SingleChildScrollView).first,
        const Offset(0, -80),
      );
      expect(find.byKey(const Key('hr-form-save')), findsOneWidget);
    });
  });

  group('F12/F14 — أنواع الإجازة بلغة الواجهة وبلفظ قرارها', () {
    testWidgets('الواجهة الإنجليزية تقرأ الاسم الإنجليزي', (tester) async {
      AppLocale.instance.debugSet(AppLanguage.english);
      await _pump(
        tester,
        HrLeaveTypesView(
          leaveTypes: <HrLeaveType>[
            _leaveType(paid: false, tracks: false, document: false),
          ],
          onNew: () {},
        ),
      );
      expect(find.text('Annual leave'), findsOneWidget);
    });

    testWidgets('النوع غير المدفوع يقول «لا» ولا يكتفي بالرمادي', (
      tester,
    ) async {
      await _pump(
        tester,
        HrLeaveTypesView(
          leaveTypes: <HrLeaveType>[
            _leaveType(paid: false, tracks: false, document: false),
          ],
          onNew: () {},
        ),
      );
      expect(find.text('${S.hrLeaveTypePaid} • ${S.no}'), findsOneWidget);
      expect(find.text('${S.hrLeaveTypeTracks} • ${S.no}'), findsOneWidget);
    });

    testWidgets('المدفوعة تقول «نعم»', (tester) async {
      await _pump(
        tester,
        HrLeaveTypesView(
          leaveTypes: <HrLeaveType>[
            _leaveType(paid: true, tracks: true, document: true),
          ],
          onNew: () {},
        ),
      );
      expect(find.text('${S.hrLeaveTypePaid} • ${S.yes}'), findsOneWidget);
    });

    test('اسم النوع يهبط للسان الآخر حين يخلو لسان الواجهة', () {
      AppLocale.instance.debugSet(AppLanguage.english);
      expect(
        hrLeaveTypeName(
          HrLeaveType(
            id: 'lt-2',
            code: 'sick',
            nameAr: 'إجازة مرضية',
            nameEn: '',
            requiresDocument: false,
            isPaid: true,
            tracksBalance: true,
          ),
        ),
        'إجازة مرضية',
      );
    });
  });

  group('F13 — مرجع لم يُقرأ لا يُقرأ «لا فروع»', () {
    Future<void> pumpDiscrepancies(
      WidgetTester tester, {
      required List<HrBranch>? branches,
    }) => _pump(
      tester,
      HrDiscrepancyView(
        state: _ready(<HrDiscrepancy>[_discrepancy()]),
        search: '',
        status: null,
        branchId: null,
        branches: branches,
        canReview: true,
        onStatusChanged: (_) {},
        onBranchChanged: (_) {},
        onReview: (_) {},
        onRetry: () {},
      ),
    );

    testWidgets('الغياب يقول جملته بلا شريط ترشيح أجوّف', (tester) async {
      _setViewport(tester);
      await pumpDiscrepancies(tester, branches: null);
      expect(find.text(S.hrNoBranchesForMe), findsOneWidget);
      expect(find.text(S.hrFilterAllBranches), findsNothing);
    });

    testWidgets('الفروع المقروءة ترشّح نفسها', (tester) async {
      _setViewport(tester);
      await pumpDiscrepancies(tester, branches: _branches);
      expect(find.text(S.hrNoBranchesForMe), findsNothing);
      expect(find.text(S.hrFilterAllBranches), findsOneWidget);
    });
  });

  group('F16 — بطاقة البصمة داخل منطقة التمرير', () {
    Future<void> pumpMyDay(
      WidgetTester tester, {
      required double height,
    }) async {
      _setViewport(tester, height: height);
      await _pump(
        tester,
        HrMyDayBody(
          state: HrMyDayState(
            status: HrLoadStatus.ready,
            reference: HrReference.fromJson(<String, dynamic>{
              'branches': <Map<String, dynamic>>[
                <String, dynamic>{'id': 'b-1', 'name_ar': 'الروضة'},
              ],
              'my_staff_id': 's-1',
            }),
          ),
          search: '',
          onClockIn: (_) {},
          onClockOut: () {},
          onBreakStart: () {},
          onBreakEnd: () {},
          onCancelLeave: (_) {},
          onRequestLeave: () {},
          onRequestAdvance: () {},
        ),
      );
    }

    testWidgets('شاشة قصيرة لا تنصبّ فيها البطاقة تُقصّ زرّ البداية', (
      tester,
    ) async {
      await pumpMyDay(tester, height: 300);
      expect(tester.takeException(), isNull);
    });

    testWidgets('زرّ بداية الدوام يُطلب من داخل التمرير', (tester) async {
      await pumpMyDay(tester, height: 300);
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text(S.hrBtnClockIn),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('F6 — خلية فارغة واحدة لكل الأعمدة', (tester) async {
    await _pump(tester, const HrCellText(''));
    expect(find.text(S.hrNoValue), findsOneWidget);
  });
}
