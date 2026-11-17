import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employment_draft.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_employee_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employee_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employee_state.dart';

void main() {
  test(
    'loads employee and saves employment without touching identity',
    () async {
      final repository = _Repository();
      final cubit = HrEmployeeCubit(repository: repository);
      await cubit.load('staff-1');
      expect(cubit.state.status, HrEmployeeStatus.ready);
      expect(cubit.state.employee?.email, 'employee@example.com');

      final ok = await cubit.saveEmployment(
        const HrEmploymentDraft(employeeNumber: 'E-5', department: 'Sales'),
      );

      expect(ok, isTrue);
      expect(cubit.state.employee?.email, 'employee@example.com');
      expect(cubit.state.employee?.employment?.employeeNumber, 'E-5');
      expect(repository.savedStaffId, 'staff-1');
      expect(cubit.state.saved, isTrue);
      await cubit.close();
    },
  );

  test('keeps failure visible and returns false when save is denied', () async {
    final repository = _Repository()..failSave = true;
    final cubit = HrEmployeeCubit(repository: repository);
    await cubit.load('staff-1');
    final ok = await cubit.saveEmployment(const HrEmploymentDraft());
    expect(ok, isFalse);
    expect(cubit.state.status, HrEmployeeStatus.ready);
    expect(cubit.state.errorMessage, isNotNull);
    await cubit.close();
  });
}

class _Repository implements HrEmployeeRepository {
  bool failSave = false;
  String? savedStaffId;

  @override
  Future<HrEmployeeFile> loadEmployee(String staffId) async =>
      const HrEmployeeFile(
        staffId: 'staff-1',
        userId: 'user-1',
        fullName: 'Employee',
        email: 'employee@example.com',
        accountStatus: 'active',
      );

  @override
  Future<HrEmploymentDraft> saveEmployment({
    required String staffId,
    required HrEmploymentDraft employment,
  }) async {
    savedStaffId = staffId;
    if (failSave) throw Exception('Permission denied');
    return employment;
  }
}
