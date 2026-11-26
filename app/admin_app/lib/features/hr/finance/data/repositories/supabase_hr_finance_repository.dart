import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_app/core/services/supabase_service.dart';

import '../../domain/models/hr_finance_models.dart';
import '../../domain/repositories/hr_finance_repository.dart';

class SupabaseHrFinanceRepository implements HrFinanceRepository {
  SupabaseHrFinanceRepository({this._client});
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? SupabaseService.client;

  @override
  Future<List<HrAdvance>> loadAdvances() async => _rows(
    await client.rpc(
      'admin_hr_advances',
      params: {'p_status': null, 'p_staff_id': null, 'p_limit': 100},
    ),
  ).map(HrAdvance.fromJson).toList(growable: false);

  @override
  Future<List<HrAdjustment>> loadAdjustments() async => _rows(
    await client.rpc(
      'admin_hr_adjustments',
      params: {
        'p_status': null,
        'p_staff_id': null,
        'p_source_type': null,
        'p_limit': 100,
      },
    ),
  ).map(HrAdjustment.fromJson).toList(growable: false);

  @override
  Future<List<HrDiscrepancy>> loadDiscrepancies() async => _rows(
    await client.rpc(
      'admin_hr_discrepancies',
      params: {'p_status': null, 'p_branch_id': null, 'p_limit': 100},
    ),
  ).map(HrDiscrepancy.fromJson).toList(growable: false);

  @override
  Future<List<HrFinanceEmployee>> loadEmployees() async => _rows(
    await client.rpc(
      'admin_hr_employees',
      params: {
        'p_search': null,
        'p_branch_id': null,
        'p_status': null,
        'p_department': null,
      },
    ),
  ).map(HrFinanceEmployee.fromJson).toList(growable: false);

  @override
  Future<bool> loadCashierDeductionEnabled() async {
    final raw = await client.rpc('admin_hr_reference');
    return raw is Map &&
        raw['settings'] is Map &&
        (raw['settings'] as Map)['cashier_deduction_allowed'] == true;
  }

  @override
  Future<void> reviewAdvance(
    String id,
    bool approve,
    double? installment,
    String? note,
  ) async {
    await client.rpc(
      'admin_hr_review_advance',
      params: {
        'p_advance_id': id,
        'p_approve': approve,
        'p_installment': installment,
        'p_note': note,
      },
    );
  }

  @override
  Future<void> disburseAdvance(String id, String? note) async => client.rpc(
    'admin_hr_disburse_advance',
    params: {'p_advance_id': id, 'p_note': note},
  );

  @override
  Future<void> cancelAdvance(String id, String? note) async => client.rpc(
    'admin_hr_cancel_advance',
    params: {'p_advance_id': id, 'p_note': note},
  );

  @override
  Future<void> createAdjustment(
    String staffId,
    String kind,
    double amount,
    String reason,
    String? date,
  ) async {
    await client.rpc(
      'admin_hr_create_adjustment',
      params: {
        'p_staff_id': staffId,
        'p_kind': kind,
        'p_amount': amount,
        'p_reason': reason,
        'p_effective_date': date,
        'p_quantity': null,
      },
    );
  }

  @override
  Future<void> reviewAdjustment(String id, bool approve, String? note) async =>
      client.rpc(
        'admin_hr_review_adjustment',
        params: {'p_adjustment_id': id, 'p_approve': approve, 'p_note': note},
      );

  @override
  Future<void> reverseAdjustment(String id, String reason) async => client.rpc(
    'admin_hr_reverse_adjustment',
    params: {'p_adjustment_id': id, 'p_reason': reason},
  );

  @override
  Future<void> reviewDiscrepancy({
    required String id,
    required String action,
    String? note,
    String? evidence,
    String? attributedStaffId,
    double? deductionAmount,
  }) async {
    await client.rpc(
      'admin_hr_review_discrepancy',
      params: {
        'p_discrepancy_id': id,
        'p_action': action,
        'p_note': note,
        'p_evidence': evidence,
        'p_attributed_staff': attributedStaffId,
        'p_deduction_amount': deductionAmount,
      },
    );
  }

  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false)
      : const [];
}
