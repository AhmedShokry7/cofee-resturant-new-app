import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employment_draft.dart';

abstract interface class HrEmployeeRepository {
  Future<HrEmployeeFile> loadEmployee(String staffId);

  Future<HrEmploymentDraft> saveEmployment({
    required String staffId,
    required HrEmploymentDraft employment,
  });
}
