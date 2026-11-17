import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/hr/data/repositories/supabase_hr_employee_repository.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employment_draft.dart';

import 'helpers/stub_supabase_client.dart';

void main() {
  test('loads the employee file through the scoped HR RPC', () async {
    final client = StubSupabaseClient(
      payload: <String, dynamic>{
        'staff_id': 'staff-1',
        'user_id': 'user-1',
        'full_name': 'Sam Staff',
        'email': 'sam@example.com',
        'account_status': 'active',
        'employment': <String, dynamic>{
          'employee_number': 'E-12',
          'department': 'Cafe',
        },
        'attendance': null,
        'payslips': null,
      },
    );

    final employee = await SupabaseHrEmployeeRepository(client)
        .loadEmployee('staff-1');

    expect(client.lastRpc, 'admin_hr_employee');
    expect(client.lastParams, <String, dynamic>{'p_staff_id': 'staff-1'});
    expect(employee.staffId, 'staff-1');
    expect(employee.employment?.employeeNumber, 'E-12');
    expect(employee.attendance, isNull);
    expect(employee.payslips, isNull);
  });

  test('saves employment only and maps all RPC parameters', () async {
    final client = StubSupabaseClient(
      payload: <String, dynamic>{
        'employee_number': 'E-13',
        'department': 'Operations',
        'job_title': 'Lead',
        'employment_type': 'full_time',
        'employment_status': 'active',
        'hired_on': '2025-03-04',
        'terminated_on': null,
        'phone': '+966500000000',
        'emergency_contact_name': 'Contact',
        'emergency_contact_phone': '123',
        'notes': 'Updated',
      },
    );
    final draft = HrEmploymentDraft(
      employeeNumber: 'E-13',
      department: 'Operations',
      jobTitle: 'Lead',
      hiredOn: DateTime(2025, 3, 4),
      phone: '+966500000000',
      emergencyContactName: 'Contact',
      emergencyContactPhone: '123',
      notes: 'Updated',
    );

    final saved = await SupabaseHrEmployeeRepository(client)
        .saveEmployment(staffId: 'staff-1', employment: draft);

    expect(client.lastRpc, 'admin_hr_save_employment');
    expect(client.lastParams, <String, dynamic>{
      'p_staff_id': 'staff-1',
      'p_employee_number': 'E-13',
      'p_department': 'Operations',
      'p_job_title': 'Lead',
      'p_employment_type': 'full_time',
      'p_employment_status': 'active',
      'p_hired_on': '2025-03-04',
      'p_terminated_on': null,
      'p_phone': '+966500000000',
      'p_emergency_contact_name': 'Contact',
      'p_emergency_contact_phone': '123',
      'p_notes': 'Updated',
    });
    expect(client.lastParams!.keys, isNot(contains('email')));
    expect(saved.hiredOn, DateTime(2025, 3, 4));
  });

  test('rejects malformed RPC payloads', () async {
    final client = StubSupabaseClient(payload: <String>[]);
    final repository = SupabaseHrEmployeeRepository(client);
    await expectLater(
      repository.loadEmployee('staff-1'),
      throwsFormatException,
    );
  });
}
