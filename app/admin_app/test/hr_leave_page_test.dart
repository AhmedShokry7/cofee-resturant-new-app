import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/hr/leave/domain/models/hr_leave_models.dart';
import 'package:admin_app/features/hr/leave/domain/repositories/hr_leave_repository.dart';
import 'package:admin_app/features/hr/leave/presentation/hr_leave_strings.dart';
import 'package:admin_app/features/hr/leave/presentation/manager/hr_leave_cubit.dart';
import 'package:admin_app/features/hr/leave/presentation/pages/hr_leave_page.dart';

class _LeaveRepository implements HrLeaveRepository {
  int approveCalls = 0;
  int rejectCalls = 0;
  HrLeaveType? addedType;
  HrLeaveRequest request = HrLeaveRequest(
    id: 'leave-1',
    staffId: 'staff-1',
    staffName: 'Sara Noor',
    leaveTypeId: 'type-1',
    typeNameAr: 'سنوية',
    typeNameEn: 'Annual',
    startsOn: DateTime(2026, 12, 1),
    endsOn: DateTime(2026, 12, 3),
    days: 3,
    status: 'pending',
    reason: 'Family trip',
    tracksBalance: true,
    balance: const {
      'year': 2026,
      'entitled_days': 21,
      'used_days': 2,
      'remaining_days': 19,
    },
  );

  @override
  Future<List<HrLeaveType>> loadTypes() async => [
    const HrLeaveType(
      id: 'type-1',
      code: 'annual',
      nameAr: 'سنوية',
      nameEn: 'Annual',
      tracksBalance: true,
    ),
  ];

  @override
  Future<List<HrLeaveRequest>> loadRequests({String? status}) async =>
      status == null || request.status == status ? [request] : [];

  @override
  Future<void> reviewRequest({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    if (approve) {
      approveCalls++;
    } else {
      rejectCalls++;
    }
    request = HrLeaveRequest(
      id: request.id,
      staffId: request.staffId,
      staffName: request.staffName,
      leaveTypeId: request.leaveTypeId,
      typeNameAr: request.typeNameAr,
      typeNameEn: request.typeNameEn,
      startsOn: request.startsOn,
      endsOn: request.endsOn,
      days: request.days,
      status: approve ? 'approved' : 'rejected',
      reason: request.reason,
      reviewNote: note,
      tracksBalance: request.tracksBalance,
      balance: request.balance,
    );
  }

  @override
  Future<void> setBalance({
    required String staffId,
    required String leaveTypeId,
    required int year,
    required double entitledDays,
  }) async {}

  @override
  Future<void> saveType(HrLeaveType type, {bool create = false}) async {
    addedType = type;
  }
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('reviewer can approve a pending leave request', (tester) async {
    final repository = _LeaveRepository();
    final cubit = HrLeaveCubit(repository: repository);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HrLeavePage(
            canReview: true,
            canManageTypes: true,
            cubit: cubit,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sara Noor'), findsOneWidget);
    expect(find.text(HrLeaveStrings.approve), findsOneWidget);
    expect(find.text(HrLeaveStrings.balance), findsOneWidget);
    expect(find.text(HrLeaveStrings.leaveTypes), findsOneWidget);

    await tester.tap(find.text(HrLeaveStrings.approve));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, HrLeaveStrings.save));
    await tester.pumpAndSettle();

    expect(repository.approveCalls, 1);
    expect(repository.rejectCalls, 0);
    await cubit.close();
  });

  testWidgets(
    'review actions and type controls are hidden without permission',
    (tester) async {
      final cubit = HrLeaveCubit(repository: _LeaveRepository());
      await cubit.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HrLeavePage(
              canReview: false,
              canManageTypes: false,
              cubit: cubit,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(HrLeaveStrings.approve), findsNothing);
      expect(find.text(HrLeaveStrings.reject), findsNothing);
      expect(find.text(HrLeaveStrings.balance), findsNothing);
      expect(find.text(HrLeaveStrings.leaveTypes), findsNothing);
      await cubit.close();
    },
  );

  test('leave status label supports Arabic and English', () {
    expect(
      HrLeaveType.fromJson({
        'id': 'annual',
        'code': 'annual',
        'name_ar': 'سنوية',
        'name_en': 'Annual',
        'tracks_balance': true,
      }).label(false),
      'Annual',
    );
    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(HrLeaveStrings.title, 'إدارة الإجازات');
  });
}
