import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/features/hr/offboarding/domain/offboarding_models.dart';
import 'package:admin_app/features/hr/offboarding/domain/offboarding_repository.dart';
import 'package:admin_app/features/hr/offboarding/presentation/hr_offboarding_page.dart';
import 'package:admin_app/features/hr/offboarding/presentation/hr_offboarding_strings.dart';

void main() {
  testWidgets('termination and access suspension are separate actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeOffboardingRepository([
      _case('open-1', 'Open employee', 'open', accessStatus: 'pending'),
      _case('closed-1', 'Closed employee', 'closed', accessStatus: 'pending'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HrOffboardingPage(
            canRead: true,
            canWrite: true,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open employee'));
    await tester.pumpAndSettle();
    expect(find.text(HrOffboardingStrings.finalize), findsOneWidget);
    expect(find.text(HrOffboardingStrings.suspendAccess), findsNothing);

    await tester.tap(find.text('Open employee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Closed employee'));
    await tester.pumpAndSettle();
    expect(find.text(HrOffboardingStrings.finalize), findsNothing);
    expect(find.text(HrOffboardingStrings.suspendAccess), findsOneWidget);
  });

  testWidgets('read-only access can review cases but has no mutation actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeOffboardingRepository([
      _case('open-1', 'Open employee', 'open', accessStatus: 'pending'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HrOffboardingPage(
            canRead: true,
            canWrite: false,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open employee'));
    await tester.pumpAndSettle();

    expect(find.text(HrOffboardingStrings.start), findsNothing);
    expect(find.text(HrOffboardingStrings.cancelCase), findsNothing);
    expect(find.text(HrOffboardingStrings.finalize), findsNothing);
    expect(find.byTooltip(HrOffboardingStrings.assign), findsNothing);
  });

  testWidgets('without read permission the repository is not called', (
    tester,
  ) async {
    final repository = _FakeOffboardingRepository([]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HrOffboardingPage(
            canRead: false,
            canWrite: true,
            repository: repository,
          ),
        ),
      ),
    );

    expect(find.text(HrOffboardingStrings.accessDenied), findsOneWidget);
    expect(repository.loadCalls, 0);
  });
}

HrOffboardingCase _case(
  String id,
  String staffName,
  String status, {
  required String accessStatus,
}) => HrOffboardingCase(
  caseId: id,
  staffId: 'staff-$id',
  staffName: staffName,
  status: status,
  employmentStatus: status == 'closed' ? 'terminated' : 'active',
  lastWorkingOn: DateTime(2026, 12, 1),
  settlementNote: status == 'closed' ? 'Reviewed; signed memo FIN-12.' : '',
  steps: [
    for (final code in const [
      'manager_review',
      'hr_review',
      'finance_review',
      'obligations',
      'final_settlement',
    ])
      HrOffboardingStep(
        code: code,
        status: code == 'final_settlement' ? 'done' : 'done',
        note: 'Reviewed.',
      ),
    HrOffboardingStep(code: 'access_suspension', status: accessStatus),
  ],
);

class _FakeOffboardingRepository implements HrOffboardingRepository {
  _FakeOffboardingRepository(this.cases);
  final List<HrOffboardingCase> cases;
  int loadCalls = 0;

  @override
  Future<List<HrOffboardingCase>> loadCases() async {
    loadCalls++;
    return cases;
  }

  @override
  Future<List<HrOffboardingPerson>> loadPeople() async => const [
    HrOffboardingPerson(
      staffId: 'staff-1',
      name: 'New employee',
      email: 'new@example.com',
    ),
  ];

  @override
  Future<HrOffboardingCase> startCase({
    String staffId = '',
    DateTime? lastWorkingOn,
    String note = '',
  }) async => cases.first;

  @override
  Future<HrOffboardingCase> assignStep({
    required String caseId,
    required String code,
    String? ownerStaffId,
    DateTime? dueOn,
  }) async => cases.first;

  @override
  Future<HrOffboardingCase> setStep({
    required String caseId,
    required String code,
    required String status,
    String note = '',
  }) async => cases.first;

  @override
  Future<HrOffboardingCase> cancelCase({
    required String caseId,
    String note = '',
  }) async => cases.first;

  @override
  Future<HrOffboardingCase> finalizeCase({
    required String caseId,
    required DateTime terminatedOn,
    required String settlementNote,
  }) async => cases.first;

  @override
  Future<HrOffboardingCase> suspendAccess({
    required String caseId,
    String note = '',
  }) async => cases.first;
}
