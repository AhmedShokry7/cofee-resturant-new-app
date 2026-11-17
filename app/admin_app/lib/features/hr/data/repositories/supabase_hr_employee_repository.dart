import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/hr/data/models/hr_employee_file_model.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employment_draft.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_employee_repository.dart';

class SupabaseHrEmployeeRepository implements HrEmployeeRepository {
  SupabaseHrEmployeeRepository([SupabaseClient? client])
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  @override
  Future<HrEmployeeFile> loadEmployee(String staffId) async {
    final raw = await _client.rpc<Object?>(
      'admin_hr_employee',
      params: <String, dynamic>{'p_staff_id': staffId},
    );
    if (raw is! Map) throw const FormatException('Invalid employee file');
    return HrEmployeeFileModel.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<HrEmploymentDraft> saveEmployment({
    required String staffId,
    required HrEmploymentDraft employment,
  }) async {
    final raw = await _client.rpc<Object?>(
      'admin_hr_save_employment',
      params: employment.toJson(staffId: staffId),
    );
    if (raw is! Map) throw const FormatException('Invalid employment result');
    return HrEmploymentDraft.fromJson(Map<String, dynamic>.from(raw));
  }
}
