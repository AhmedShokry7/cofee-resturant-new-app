import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_finance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_money_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_people_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_adjustments_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_advances_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_cubit.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_advances_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// اعتماد السلفة يسأل قسطًا اختياريًا. كان الحقل يقرأ اللاتينية وحدها، فـ«٣٠٠»
/// تمرّ اعتمادًا بلا قسط، والنصّ الحرفيّ كذلك: القسط الذي كتبه المدير يختفي
/// ولا يقول أحد إنه لم يُقرأ.

class _MoneyFake implements HrMoneyRepository {
  List<HrAdvance> advances = <HrAdvance>[
    HrAdvance.fromJson(<String, dynamic>{
      'id': 'adv-1',
      'staff_id': 's-1',
      'staff_name': 'سارة',
      'amount': 900,
      'status': 'pending',
    }),
  ];

  /// ما وصل المستودع فعلًا من قرار الاعتماد.
  double? sentInstallment;
  int reviewCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<List<HrAdvance>> loadAdvances({
    String? status,
    String? staffId,
    int limit = 50,
  }) async => advances;

  @override
  Future<HrReceipt> reviewAdvance({
    required String advanceId,
    required bool approve,
    double? installment,
    String? note,
  }) async {
    reviewCalls += 1;
    sentInstallment = installment;
    return HrReceipt.fromJson(<String, dynamic>{
      'id': advanceId,
      'status': approve ? 'approved' : 'rejected',
    });
  }
}

class _PeopleFake implements HrPeopleRepository {
  @override
  Future<HrReference> loadReference() async =>
      HrReference.fromJson(<String, dynamic>{
        'branches': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'b-1',
            'name_ar': 'الروضة',
            'name_en': 'Rawdah',
          },
        ],
        'my_staff_id': 's-1',
      });

  @override
  Future<List<HrEmployee>> loadEmployees({
    String? search,
    String? branchId,
    String? status,
    String? department,
  }) async => const <HrEmployee>[
    HrEmployee(
      staffId: 's-1',
      userId: 'u-1',
      fullName: 'سارة',
      email: 's@x.com',
      accountStatus: 'active',
      employment: HrEmployment(jobTitle: 'كاشير'),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _MoneyFake money;
  late HrAdvancesCubit advances;
  late HrAdjustmentsCubit adjustments;
  late HrReferenceCubit reference;

  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    money = _MoneyFake();
    advances = HrAdvancesCubit(repository: money);
    adjustments = HrAdjustmentsCubit(repository: money);
    reference = HrReferenceCubit(repository: _PeopleFake());
  });

  tearDown(() async {
    await advances.close();
    await adjustments.close();
    await reference.close();
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await advances.reload();
    await reference.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: Scaffold(
          body: Directionality(
            textDirection: AppLocale.instance.textDirection,
            child: HrAdvancesPage(
              searchController: AdminSearchController(),
              canReview: true,
              advances: advances,
              adjustments: adjustments,
              reference: reference,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> approveWith(WidgetTester tester, String text) async {
    await pumpPage(tester);
    await tester.tap(find.text(S.hrBtnApprove).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.tap(find.byKey(const Key('hr-note-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('قسطٌ بأرقام عربية يصل المستودع رقمًا', (tester) async {
    await approveWith(tester, '٣٠٠');

    expect(money.reviewCalls, 1);
    expect(money.sentInstallment, 300);
  });

  testWidgets('قسطٌ غير رقمي يُرفض ولا يمرّ بلا قسط', (tester) async {
    await approveWith(tester, 'ثلاثمئة');

    expect(money.reviewCalls, 0);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(S.invalidNumber), findsOneWidget);
  });

  testWidgets('الحقل الفارغ يبقى قسطًا اختياريًا بلا رفض', (tester) async {
    await approveWith(tester, '');

    expect(money.reviewCalls, 1);
    expect(money.sentInstallment, isNull);
  });
}
