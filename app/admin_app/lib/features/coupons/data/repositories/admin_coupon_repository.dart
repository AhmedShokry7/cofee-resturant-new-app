import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_draft.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_targets.dart';
import 'package:admin_app/features/coupons/domain/repositories/coupon_repository.dart';

class AdminCouponRepository implements CouponRepository {
  AdminCouponRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminCoupon>> loadCoupons() async {
    final response = await _supabase.rpc('admin_coupons');
    return _mapList(response, AdminCoupon.fromJson);
  }

  @override
  Future<AdminCouponMetrics> loadMetrics() async {
    final response = await _supabase.rpc('admin_coupon_metrics');
    if (response is Map) {
      return AdminCouponMetrics.fromJson(Map<String, dynamic>.from(response));
    }
    return AdminCouponMetrics.empty;
  }

  @override
  Future<AdminCouponTargets> loadTargets() async {
    final response = await _supabase.rpc('admin_coupon_targets');
    if (response is Map) {
      return AdminCouponTargets.fromJson(Map<String, dynamic>.from(response));
    }
    return AdminCouponTargets.empty;
  }

  @override
  Future<CouponSaveOutcome> saveCoupon(AdminCouponDraft draft) async {
    final response = await _supabase.rpc(
      'admin_save_coupon',
      params: {'p_coupon': draft.toJson()},
    );
    if (_isOk(response)) return CouponSaveOutcome.saved;
    return switch (_reason(response)) {
      'duplicate_code' => CouponSaveOutcome.duplicateCode,
      'invalid_code' => CouponSaveOutcome.invalidCode,
      'invalid_title' => CouponSaveOutcome.invalidTitle,
      'invalid_discount' => CouponSaveOutcome.invalidDiscount,
      'invalid_limit' => CouponSaveOutcome.invalidLimit,
      'invalid_window' => CouponSaveOutcome.invalidWindow,
      'invalid_scope' => CouponSaveOutcome.invalidScope,
      'not_found' => CouponSaveOutcome.notFound,
      _ => CouponSaveOutcome.failed,
    };
  }

  @override
  Future<CouponMutationOutcome> setCouponActive(
    String couponId,
    bool active,
  ) async {
    final response = await _supabase.rpc(
      'admin_set_coupon_active',
      params: {'p_coupon_id': couponId, 'p_active': active},
    );
    if (_isOk(response)) return CouponMutationOutcome.success;
    return switch (_reason(response)) {
      'not_found' => CouponMutationOutcome.notFound,
      _ => CouponMutationOutcome.failed,
    };
  }

  @override
  Future<CouponMutationOutcome> deleteCoupon(String couponId) async {
    final response = await _supabase.rpc(
      'admin_delete_coupon',
      params: {'p_coupon_id': couponId},
    );
    if (_isOk(response)) return CouponMutationOutcome.success;
    return switch (_reason(response)) {
      'not_found' => CouponMutationOutcome.notFound,
      'has_redemptions' => CouponMutationOutcome.hasRedemptions,
      _ => CouponMutationOutcome.failed,
    };
  }

  static bool _isOk(Object? response) =>
      response is Map && response['ok'] == true;

  static String _reason(Object? response) =>
      response is Map ? '${response['reason'] ?? ''}' : '';

  static List<T> _mapList<T>(
    Object? response,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (response is! List) return <T>[];
    return response
        .whereType<Map>()
        .map((row) => fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}
