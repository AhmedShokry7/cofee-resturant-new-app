import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_app/core/services/supabase_service.dart';

import '../domain/hr_payroll_models.dart';
import '../domain/hr_payroll_repository.dart';

class SupabaseHrPayrollRepository implements HrPayrollRepository {
  SupabaseHrPayrollRepository({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? SupabaseService.client;

  @override
  Future<List<HrPayrollRun>> loadRuns() async {
    final raw = await client.rpc(
      'admin_hr_payroll_runs',
      params: {'p_limit': 24},
    );
    return hrJsonList(raw).map(HrPayrollRun.fromJson).toList(growable: false);
  }

  @override
  Future<HrJson> loadRun(String id) async =>
      hrJson(
        await client.rpc('admin_hr_payroll_run', params: {'p_run_id': id}),
      ) ??
      <String, dynamic>{};

  @override
  Future<HrPayrollPreview> preview(int year, int month) async =>
      HrPayrollPreview.fromJson(
        hrJson(
              await client.rpc(
                'admin_hr_preview_payroll',
                params: {'p_period_year': year, 'p_period_month': month},
              ),
            ) ??
            <String, dynamic>{},
      );

  @override
  Future<void> generate(int year, int month, String? note) async {
    await client.rpc(
      'admin_hr_generate_payroll',
      params: {'p_period_year': year, 'p_period_month': month, 'p_note': note},
    );
  }

  @override
  Future<void> approve(String runId, String? note) async {
    await client.rpc(
      'admin_hr_approve_payroll',
      params: {'p_run_id': runId, 'p_note': note},
    );
  }

  @override
  Future<void> markPaid(String runId, String? reference) async {
    await client.rpc(
      'admin_hr_pay_payroll',
      params: {'p_run_id': runId, 'p_note': reference},
    );
  }

  @override
  Future<void> cancel(String runId, String reason) async {
    await client.rpc(
      'admin_hr_cancel_payroll_run',
      params: {'p_run_id': runId, 'p_note': reason},
    );
  }

  @override
  Future<void> closePeriod(String runId, String? note) async {
    await client.rpc(
      'admin_hr_close_payroll_period',
      params: {'p_run_id': runId, 'p_note': note},
    );
  }

  @override
  Future<void> correction({
    required String statementId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
  }) async {
    await client.rpc(
      'admin_hr_payroll_correction',
      params: {
        'p_statement_id': statementId,
        'p_kind': kind,
        'p_amount': amount,
        'p_reason': reason,
        'p_effective_date': effectiveDate == null
            ? null
            : '${effectiveDate.year.toString().padLeft(4, '0')}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}',
      },
    );
  }
}
