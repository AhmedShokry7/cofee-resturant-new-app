import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/compensation/domain/hr_compensation_repository.dart';
import 'package:admin_app/features/hr/compensation/presentation/hr_compensation_cubit.dart';
import 'package:admin_app/features/hr/compensation/presentation/hr_compensation_page.dart';

class _FakeCompensationRepository implements HrCompensationRepository {
  int employeeLoads = 0;
  Map<String, dynamic> compensation = {
    'current': {
      'basic_salary': 5000,
      'housing_allowance': 1000,
      'transport_allowance': 400,
      'other_allowance': 0,
      'currency_code': 'SAR',
      'effective_from': '2026-01-01',
    },
    'history': [
      {
        'basic_salary': 5000,
        'allowances': 1400,
        'currency_code': 'SAR',
        'effective_from': '2026-01-01',
        'effective_to': null,
        'note': 'Initial',
      },
    ],
  };
  Map<String, Object?>? saved;

  @override
  Future<List<HrCompensationEmployee>> loadEmployees() async {
    employeeLoads++;
    return const [
      HrCompensationEmployee(
        staffId: 'staff-1',
        fullName: 'Ahmed Ali',
        employeeNumber: 'E-1',
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>?> loadEmployeeCompensation(
    String staffId,
  ) async => compensation;

  @override
  Future<void> addCompensation({
    required String staffId,
    required double basicSalary,
    required double housingAllowance,
    required double transportAllowance,
    required double otherAllowance,
    required DateTime effectiveFrom,
    required String note,
  }) async {
    saved = {
      'staffId': staffId,
      'basicSalary': basicSalary,
      'housingAllowance': housingAllowance,
      'transportAllowance': transportAllowance,
      'otherAllowance': otherAllowance,
      'effectiveFrom': effectiveFrom,
      'note': note,
    };
  }
}

void main() {
  testWidgets('salary data is not fetched without compensation permission', (
    tester,
  ) async {
    final repository = _FakeCompensationRepository();
    final cubit = HrCompensationCubit(repository: repository);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HrCompensationPage(canManage: false, cubit: cubit),
        ),
      ),
    );
    await tester.pump();

    expect(repository.employeeLoads, 0);
    expect(find.text('5000'), findsNothing);
    expect(find.textContaining('compensation-manage'), findsOneWidget);
    await cubit.close();
  });

  test(
    'saving an effective-dated change sends the selected employee and values',
    () async {
      final repository = _FakeCompensationRepository();
      final cubit = HrCompensationCubit(repository: repository);
      await cubit.load();
      await cubit.selectEmployee('staff-1');

      expect(cubit.state.compensation?['current']['basic_salary'], 5000);
      final effective = DateTime(2027, 1, 1);
      final saved = await cubit.addCompensation(
        basicSalary: 6000,
        housingAllowance: 1200,
        transportAllowance: 500,
        otherAllowance: 100,
        effectiveFrom: effective,
        note: 'Promotion',
      );

      expect(saved, isTrue);
      expect(repository.saved?['staffId'], 'staff-1');
      expect(repository.saved?['basicSalary'], 6000);
      expect(repository.saved?['effectiveFrom'], effective);
      expect(cubit.state.status, HrCompensationStatus.ready);
      await cubit.close();
    },
  );

  testWidgets(
    'authorized compensation page displays current and historical records',
    (tester) async {
      final repository = _FakeCompensationRepository();
      final cubit = HrCompensationCubit(repository: repository);
      await cubit.load();
      await cubit.selectEmployee('staff-1');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HrCompensationPage(canManage: true, cubit: cubit),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.hrCurrentCompensation), findsOneWidget);
      expect(find.text(S.hrCompensationHistory), findsOneWidget);
      expect(find.textContaining('5,000'), findsWidgets);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.textContaining('Initial'), findsOneWidget);
      await cubit.close();
    },
  );
}
