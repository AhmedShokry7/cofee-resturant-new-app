import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/hr/data/hr_rpc.dart';
import 'package:admin_app/features/hr/domain/entities/hr_discrepancy.dart';
import 'package:admin_app/features/hr/domain/entities/hr_finance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_money_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تنفيذ عقد المال على الأقسام 20–21 من التهيئة 212.
///
/// لا يكتب هذا المنفذ حسمًا في راتب ولا يعفي أحدًا من مراجعة: كل قرار معلق
/// حتى يمرّ بـ `review`، والفارق يظل فرقًا حتى `confirm` ثم `deduct` صريح.
class AdminHrMoneyRepository implements HrMoneyRepository {
  AdminHrMoneyRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<HrReceipt> requestAdvance({
    required double amount,
    double? installment,
    required String reason,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'hr_request_advance',
        params: <String, dynamic>{
          'p_amount': amount,
          'p_installment': installment,
          'p_reason': reason,
        },
      ),
    );
  }

  @override
  Future<List<HrAdvance>> loadAdvances({
    String? status,
    String? staffId,
    int limit = 50,
  }) async {
    final rows = await HrRpc.rows(
      _supabase,
      'admin_hr_advances',
      params: <String, dynamic>{
        'p_status': status,
        'p_staff_id': staffId,
        'p_limit': limit,
      },
    );
    return rows.map(HrAdvance.fromJson).toList();
  }

  @override
  Future<HrReceipt> reviewAdvance({
    required String advanceId,
    required bool approve,
    double? installment,
    String? note,
  }) => _advance('admin_hr_review_advance', <String, dynamic>{
    'p_advance_id': advanceId,
    'p_approve': approve,
    'p_installment': installment,
    'p_note': note,
  });

  @override
  Future<HrReceipt> disburseAdvance({
    required String advanceId,
    String? note,
  }) => _advance('admin_hr_disburse_advance', <String, dynamic>{
    'p_advance_id': advanceId,
    'p_note': note,
  });

  @override
  Future<HrReceipt> cancelAdvance({required String advanceId, String? note}) =>
      _advance('admin_hr_cancel_advance', <String, dynamic>{
        'p_advance_id': advanceId,
        'p_note': note,
      });

  @override
  Future<List<HrAdjustment>> loadAdjustments({
    String? status,
    String? staffId,
    String? sourceType,
    int limit = 60,
  }) async {
    final rows = await HrRpc.rows(
      _supabase,
      'admin_hr_adjustments',
      params: <String, dynamic>{
        'p_status': status,
        'p_staff_id': staffId,
        'p_source_type': sourceType,
        'p_limit': limit,
      },
    );
    return rows.map(HrAdjustment.fromJson).toList();
  }

  @override
  Future<HrReceipt> createAdjustment({
    required String staffId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
    double? quantity,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_create_adjustment',
        params: <String, dynamic>{
          'p_staff_id': staffId,
          'p_kind': kind,
          'p_amount': amount,
          'p_quantity': quantity,
          'p_reason': reason,
          'p_effective_date': HrRpc.day(effectiveDate),
        },
      ),
    );
  }

  @override
  Future<HrReceipt> reviewAdjustment({
    required String adjustmentId,
    required bool approve,
    String? note,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_review_adjustment',
        params: <String, dynamic>{
          'p_adjustment_id': adjustmentId,
          'p_approve': approve,
          'p_note': note,
        },
      ),
    );
  }

  @override
  Future<HrReceipt> reverseAdjustment({
    required String adjustmentId,
    required String reason,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_reverse_adjustment',
        params: <String, dynamic>{
          'p_adjustment_id': adjustmentId,
          'p_reason': reason,
        },
      ),
    );
  }

  @override
  Future<List<HrDiscrepancy>> loadDiscrepancies({
    String? status,
    String? branchId,
    int limit = 60,
  }) async {
    final rows = await HrRpc.rows(
      _supabase,
      'admin_hr_discrepancies',
      params: <String, dynamic>{
        'p_status': status,
        'p_branch_id': branchId,
        'p_limit': limit,
      },
    );
    return rows.map(HrDiscrepancy.fromJson).toList();
  }

  @override
  Future<HrDiscrepancy> reviewDiscrepancy({
    required String discrepancyId,
    required String action,
    String? note,
    String? evidence,
    String? attributedStaffId,
    double? deductionAmount,
  }) async {
    return HrDiscrepancy.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_review_discrepancy',
        params: <String, dynamic>{
          'p_discrepancy_id': discrepancyId,
          'p_action': action,
          'p_note': note,
          'p_evidence': evidence,
          'p_attributed_staff': attributedStaffId,
          'p_deduction_amount': deductionAmount,
        },
      ),
    );
  }

  Future<HrReceipt> _advance(
    String function,
    Map<String, dynamic> params,
  ) async {
    return HrReceipt.fromJson(
      await HrRpc.object(_supabase, function, params: params),
    );
  }
}
