import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_employee_file_sheet.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ملف الموظف: ما تقرأه القاعدة فقط، وكل قرار فيه بيد صاحبه وحده.
HrEmployeeFile _file({
  bool withCompensation = true,
  bool withAttendance = true,
}) => HrEmployeeFile.fromJson(<String, dynamic>{
  'staff_id': 's-1',
  'full_name': 'سارة العتيبي',
  'account_status': 'active',
  'employment': <String, dynamic>{
    'employee_number': 'E-14',
    'job_title': 'باريستا',
    'department': 'التشغيل',
    'employment_type': 'full_time',
    'employment_status': 'active',
    'hired_on': '2026-01-05',
  },
  'attendance': withAttendance
      ? <Map<String, dynamic>>[
          <String, dynamic>{
            'branch_name_ar': 'الفرع الرئيسي',
            'clock_in_local': '08:58 ص',
            'clock_out_local': '05:02 م',
            'is_open': false,
          },
        ]
      : null,
  'leave': <Map<String, dynamic>>[],
  'compensation': withCompensation
      ? <String, dynamic>{
          'current': <String, dynamic>{
            'id': 'cmp-1',
            'basic_salary': 4200,
            'housing_allowance': 600,
            'currency_code': 'SAR',
            'effective_from': '2026-01-05',
            'is_current': true,
          },
        }
      : null,
  'payslips': null,
  'advances': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'adv-1',
      'created_at': '2026-09-11',
      'amount': 1200,
      'outstanding': 900,
      'status': 'disbursed',
    },
  ],
});

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  HrEmployeeFile file, {
  VoidCallback? onEditCompensation,
  VoidCallback? onEdit,
  HrRefusal? refusal,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: HrEmployeeFileSheet(
            file: file,
            onClose: () {},
            onEdit: onEdit,
            onEditCompensation: onEditCompensation,
            refusal: refusal,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the pay editor is offered only to its own permission', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(tester, _file());
    expect(find.text(S.hrBtnSetCompensation), findsNothing);

    await _pump(tester, _file(), onEditCompensation: () {});
    expect(tester.takeException(), isNull);
    expect(find.text(S.hrBtnSetCompensation), findsOneWidget);
  });

  testWidgets('editing the contract is a separate door from editing pay', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(tester, _file(), onEdit: () {});

    expect(find.text(S.edit), findsOneWidget);
    expect(find.text(S.hrBtnSetCompensation), findsNothing);
  });

  testWidgets('money in the file wears the riyal mark, not a text suffix', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(tester, _file());

    expect(find.byType(AdminMoneyText), findsWidgets);
    expect(find.textContaining('ر.س'), findsNothing);
    expect(find.textContaining('SAR'), findsNothing);
  });

  testWidgets('a section that was not read is not called empty', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(tester, _file(withAttendance: false));

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrFileUnread), findsWidgets);
    expect(find.text(S.hrEmptyAttendance), findsNothing);
  });

  testWidgets('a compensation the reader may not see says so in words', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(tester, _file(withCompensation: false));

    expect(find.text(S.hrFileCompensationHidden), findsOneWidget);
    expect(find.text(S.hrEmptyList), findsNothing);
  });

  testWidgets('a refusal after a write lands inside the sheet, not behind it', (
    tester,
  ) async {
    _setViewport(tester, 1400);
    await _pump(
      tester,
      _file(),
      refusal: const HrRefusal(
        sqlState: '42501',
        message: 'missing permission: hr.compensation.manage',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining(S.hrMissingPermission), findsWidgets);
    expect(find.textContaining(S.hrRefusalCode), findsWidgets);
  });

  testWidgets('the file opens narrow without overflow', (tester) async {
    for (final width in <double>[360, 320]) {
      _setViewport(tester, width);
      await _pump(tester, _file(), onEdit: () {}, onEditCompensation: () {});

      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
