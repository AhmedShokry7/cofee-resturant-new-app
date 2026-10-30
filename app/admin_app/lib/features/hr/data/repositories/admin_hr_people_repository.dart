import 'package:admin_app/core/services/admin_avatar_links.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/hr/data/hr_rpc.dart';
import 'package:admin_app/features/hr/domain/entities/hr_dashboard.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_people_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تنفيذ عقد الموظفين على RPCs القسمين 13–14 و22 من التهيئة 212.
///
/// لا استعلام جدول هنا: صلاحيات مخطَّط `hr` مسحوبة من `public`، وسياسات RLS فيه
/// بلا صفوف، فالقراءة والكتابة لا تمرّان إلا من `admin_hr_*`.
class AdminHrPeopleRepository implements HrPeopleRepository {
  AdminHrPeopleRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<HrReference> loadReference() async {
    return HrReference.fromJson(
      await HrRpc.object(_supabase, 'admin_hr_reference'),
    );
  }

  @override
  Future<List<HrEmployee>> loadEmployees({
    String? search,
    String? branchId,
    String? status,
    String? department,
  }) async {
    // الصورة مسار في دلو `avatars` الخاص، فتُوقَّع هنا كما تُوقَّع صور العملاء،
    // ولا تصل إلى widget كمسار لا يقدر على جلبه.
    final payload = await AdminAvatarLinks.signTree(
      await _supabase.rpc(
        'admin_hr_employees',
        params: <String, dynamic>{
          'p_search': search,
          'p_branch_id': branchId,
          'p_status': status,
          'p_department': department,
        },
      ),
      client: _supabase,
    );
    return HrRpc.rowsOf(payload).map(HrEmployee.fromJson).toList();
  }

  @override
  Future<HrEmployeeFile> loadEmployeeFile(String staffId) async {
    final payload = await AdminAvatarLinks.signTree(
      await _supabase.rpc(
        'admin_hr_employee',
        params: <String, dynamic>{'p_staff_id': staffId},
      ),
      client: _supabase,
    );
    return HrEmployeeFile.fromJson(HrRpc.mapOf(payload));
  }

  @override
  Future<HrEmployment> saveEmployment({
    required String staffId,
    String? employeeNumber,
    String? department,
    String? jobTitle,
    String? employmentType,
    String? employmentStatus,
    DateTime? hiredOn,
    DateTime? terminatedOn,
    String? phone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? notes,
  }) async {
    final response = await HrRpc.object(
      _supabase,
      'admin_hr_save_employment',
      params: <String, dynamic>{
        'p_staff_id': staffId,
        'p_employee_number': employeeNumber,
        'p_department': department,
        'p_job_title': jobTitle,
        'p_employment_type': employmentType,
        'p_employment_status': employmentStatus,
        'p_hired_on': HrRpc.day(hiredOn),
        'p_terminated_on': HrRpc.day(terminatedOn),
        'p_phone': phone,
        'p_emergency_contact_name': emergencyContactName,
        'p_emergency_contact_phone': emergencyContactPhone,
        'p_notes': notes,
      },
    );
    return HrEmployment.fromJson(response);
  }

  @override
  Future<HrDashboard> loadDashboard({String? branchId}) async {
    return HrDashboard.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_dashboard',
        params: <String, dynamic>{'p_branch_id': branchId},
      ),
    );
  }

  @override
  Future<HrSettings> updateSettings({
    String? businessTimeZone,
    int? lateGraceMinutes,
    double? lateMinuteRate,
    double? earlyMinuteRate,
    double? absenceDayRate,
    bool? cashierDeductionAllowed,
    double? maxSalaryDeductionPercent,
  }) async {
    return HrSettings.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_update_settings',
        params: <String, dynamic>{
          'p_business_time_zone': businessTimeZone,
          'p_late_grace_minutes': lateGraceMinutes,
          'p_late_minute_rate': lateMinuteRate,
          'p_early_minute_rate': earlyMinuteRate,
          'p_absence_day_rate': absenceDayRate,
          'p_cashier_deduction_allowed': cashierDeductionAllowed,
          'p_max_salary_deduction_percent': maxSalaryDeductionPercent,
        },
      ),
    );
  }

  @override
  Future<HrReceipt> saveLeaveType({
    String? id,
    String? code,
    String? nameAr,
    String? nameEn,
    bool requiresDocument = false,
    bool isPaid = true,
    bool tracksBalance = false,
    double? defaultAnnualDays,
    bool isActive = true,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_save_leave_type',
        params: <String, dynamic>{
          'p_id': id,
          'p_code': code,
          'p_name_ar': nameAr,
          'p_name_en': nameEn,
          'p_requires_document': requiresDocument,
          'p_is_paid': isPaid,
          'p_tracks_balance': tracksBalance,
          'p_default_annual_days': defaultAnnualDays,
          'p_is_active': isActive,
        },
      ),
    );
  }
}
