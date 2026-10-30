import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_schedule.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_people_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_time_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_schedules_cubit.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_schedules_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// F7 وF8 معًا على شاشة حقيقية: المرجع يعود بعد القائمة، والمرشَّحون من الدليل
/// لا من سطور لم تُكتب بعد.
///
/// الانحدار الذي يُغلق هذا الملف هو أول وردية على قاعدةٍ بلا ورديات: الصفحة
/// قرأت `_reference.state` أمرًا مرة، فبقيت جملة «لم تُقرأ فروعك» على الشاشة
/// بعد أن نجحت `admin_hr_reference`، وحوار الجدول الجديد عدّا مرشّحيه من جداول
/// فارغة فقال «لا ملفّ في النطاق» ثم رفض الحفظ.

class _PeopleFake implements HrPeopleRepository {
  List<HrEmployee> employees = <HrEmployee>[
    const HrEmployee(
      staffId: 's-1',
      userId: 'u-1',
      fullName: 'سارة',
      email: 's@x.com',
      accountStatus: 'active',
      employment: HrEmployment(jobTitle: 'كاشير'),
    ),
  ];

  int referenceCalls = 0;

  @override
  Future<HrReference> loadReference() async {
    referenceCalls++;
    return HrReference.fromJson(<String, dynamic>{
      'branches': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'b-1',
          'name_ar': 'الروضة',
          'name_en': 'Rawdah',
        },
      ],
      'my_staff_id': 's-1',
    });
  }

  @override
  Future<List<HrEmployee>> loadEmployees({
    String? search,
    String? branchId,
    String? status,
    String? department,
  }) async => employees;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// قاعدة بلا ورديات: هذا هو بالضبط حال أول جدولة على القاعدة.
class _TimeFake implements HrTimeRepository {
  /// أول قراءة تفشل: شريط الرفض وحده هو الذي يحمل زرّ إعادة المحاولة.
  bool failOnce = false;

  @override
  Future<List<HrWorkSchedule>> loadSchedules({
    required DateTime from,
    required DateTime to,
    String? branchId,
    String? staffId,
  }) async {
    if (failOnce) {
      failOnce = false;
      throw StateError('connection reset');
    }
    return const <HrWorkSchedule>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _PeopleFake people;
  late _TimeFake time;
  late HrSchedulesCubit schedules;
  late HrReferenceCubit reference;

  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    people = _PeopleFake();
    time = _TimeFake();
    schedules = HrSchedulesCubit(repository: time);
    reference = HrReferenceCubit(repository: people);
  });

  tearDown(() async {
    await schedules.close();
    await reference.close();
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(531, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        // الصفحة تُركّب داخل درج الأدمن، فالسقف هنا هو Scaffold نفسه: بلا
        // Material ancestor تنفجرINK الحقول ولا تُقرأ الشاشة أصلًا.
        home: Scaffold(
          body: Directionality(
            textDirection: AppLocale.instance.textDirection,
            child: HrSchedulesPage(
              searchController: AdminSearchController(),
              canManage: true,
              cubit: schedules,
              reference: reference,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('F7 — مرجعٌ يعود بعد القائمة يبدّل الشاشة', (tester) async {
    // ترتيب التدريب الحيّ: القراءة الأولى للجداول، ثم المرجع متأخرًا.
    await schedules.reload();
    await pumpPage(tester);
    expect(find.text(S.hrNoBranchesForMe), findsOneWidget);

    await reference.load();
    await tester.pumpAndSettle();

    expect(find.text(S.hrNoBranchesForMe), findsNothing);
    expect(find.text(S.hrFilterAllBranches), findsOneWidget);
  });

  testWidgets('F7b — إعادة المحاولة تسأل المرجع لا القائمة وحدها', (
    tester,
  ) async {
    time.failOnce = true;
    await schedules.reload();
    await pumpPage(tester);
    final before = people.referenceCalls;
    expect(find.text(S.hrNoBranchesForMe), findsOneWidget);

    await tester.tap(find.text(S.retry));
    await tester.pumpAndSettle();

    expect(people.referenceCalls, greaterThan(before));
    expect(find.text(S.hrNoBranchesForMe), findsNothing);
    expect(find.text(S.hrFilterAllBranches), findsOneWidget);
  });

  testWidgets('F8 — قاعدة بلا ورديات تفتح حوارها على مرشَّحي الدليل', (
    tester,
  ) async {
    await schedules.reload();
    await reference.load();
    await pumpPage(tester);

    await tester.tap(find.text(S.hrBtnNewSchedule));
    await tester.pumpAndSettle();

    expect(find.text(S.hrScheduleTitle), findsOneWidget);
    // لا «لا ملفّ في النطاق» ولا حقل أجوّف: الدليل قرئ، فاسمه يُعرض.
    expect(find.text('سارة'), findsWidgets);
    expect(find.text(S.hrEmptyEmployees), findsNothing);
  });

  testWidgets('F8 — دليل رُفض يُقال مرفوضًا ولا يُخترع موظف', (tester) async {
    // صلاحية لا تقرأ admin_hr_employees: المرجع يبقى مقروءًا للدليل الآخر.
    reference = HrReferenceCubit(repository: _RefusedDirectory());
    await schedules.reload();
    await reference.load();
    await pumpPage(tester);

    await tester.tap(find.text(S.hrBtnNewSchedule));
    await tester.pumpAndSettle();

    expect(find.text(S.hrEmployeesUnread), findsOneWidget);
  });
}

/// مرجعٌ يقرأ الفروع ويدليلٌ يرفض: الحالتان منفصلتان في العقدة منذ F8.
class _RefusedDirectory implements HrPeopleRepository {
  @override
  Future<HrReference> loadReference() async =>
      HrReference.fromJson(<String, dynamic>{
        'branches': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'b-1', 'name_ar': 'الروضة'},
        ],
        'my_staff_id': 's-1',
      });

  @override
  Future<List<HrEmployee>> loadEmployees({
    String? search,
    String? branchId,
    String? status,
    String? department,
  }) async => throw StateError('42501 hr.employee.read');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
