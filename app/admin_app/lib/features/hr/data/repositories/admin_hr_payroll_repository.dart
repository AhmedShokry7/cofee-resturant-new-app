import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/hr/data/hr_rpc.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll_preview.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_payroll_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تنفيذ عقد الرواتب على الأقسام 18–19 من التهيئة 212.
///
/// الحساب والاعتماد والدفع ثلاث أفعال منفصلة في القاعدة، والمنفذ هنا يوصلها
/// كما هي: لا يجمع شاشة أسطرًا ليصل إلى إجمالي، ولا يعتمد دورة من يديرها.
class AdminHrPayrollRepository implements HrPayrollRepository {
  AdminHrPayrollRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<HrReceipt> setCompensation({
    required String staffId,
    required double basicSalary,
    double housingAllowance = 0,
    double transportAllowance = 0,
    double otherAllowance = 0,
    DateTime? effectiveFrom,
    String? note,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_set_compensation',
        params: <String, dynamic>{
          'p_staff_id': staffId,
          'p_basic_salary': basicSalary,
          'p_housing_allowance': housingAllowance,
          'p_transport_allowance': transportAllowance,
          'p_other_allowance': otherAllowance,
          'p_effective_from': HrRpc.day(effectiveFrom),
          'p_note': note,
        },
      ),
    );
  }

  @override
  Future<HrReceipt> generatePayroll({
    required int periodYear,
    required int periodMonth,
    String? note,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_generate_payroll',
        params: <String, dynamic>{
          'p_period_year': periodYear,
          'p_period_month': periodMonth,
          'p_note': note,
        },
      ),
    );
  }

  @override
  Future<List<HrPayrollRun>> loadPayrollRuns({int limit = 24}) async {
    final rows = await HrRpc.rows(
      _supabase,
      'admin_hr_payroll_runs',
      params: <String, dynamic>{'p_limit': limit},
    );
    return rows.map(HrPayrollRun.fromJson).toList();
  }

  @override
  Future<HrPayrollRun> loadPayrollRun(String runId) async {
    return HrPayrollRun.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_payroll_run',
        params: <String, dynamic>{'p_run_id': runId},
      ),
    );
  }

  @override
  Future<HrPayrollStatement> loadStatement(String statementId) async {
    return HrPayrollStatement.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_statement',
        params: <String, dynamic>{'p_statement_id': statementId},
      ),
    );
  }

  @override
  Future<List<HrPayrollStatement>> loadMyPayslips() async {
    final rows = await HrRpc.rows(_supabase, 'hr_my_payslips');
    return rows.map(HrPayrollStatement.fromJson).toList();
  }

  @override
  Future<HrReceipt> approvePayroll({required String runId, String? note}) =>
      _decide('admin_hr_approve_payroll', runId, note);

  @override
  Future<HrReceipt> payPayroll({required String runId, String? note}) =>
      _decide('admin_hr_pay_payroll', runId, note);

  @override
  Future<HrReceipt> cancelPayrollRun({required String runId, String? note}) =>
      _decide('admin_hr_cancel_payroll_run', runId, note);

  @override
  Future<HrReceipt> payrollCorrection({
    required String statementId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_payroll_correction',
        params: <String, dynamic>{
          'p_statement_id': statementId,
          'p_kind': kind,
          'p_amount': amount,
          'p_reason': reason,
          'p_effective_date': HrRpc.day(effectiveDate),
        },
      ),
    );
  }

  @override
  Future<HrPayrollPreview> previewPayroll({
    required int periodYear,
    required int periodMonth,
  }) async {
    return HrPayrollPreview.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_preview_payroll',
        params: <String, dynamic>{
          'p_period_year': periodYear,
          'p_period_month': periodMonth,
        },
      ),
    );
  }

  @override
  Future<HrReceipt> closePeriod({required String runId, String? note}) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_close_payroll_period',
        params: <String, dynamic>{'p_run_id': runId, 'p_note': note},
      ),
    );
  }

  Future<HrReceipt> _decide(String function, String runId, String? note) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        function,
        params: <String, dynamic>{'p_run_id': runId, 'p_note': note},
      ),
    );
  }
}
