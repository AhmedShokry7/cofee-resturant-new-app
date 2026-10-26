import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/core/delivery_zones/delivery_zone_repository.dart';
import 'package:admin_app/core/models/admin_delivery_zone.dart';
import 'package:admin_app/features/delivery_zones/domain/repositories/zone_repository.dart';

class AdminDeliveryZoneRepository
    implements DeliveryZoneRepository, ZoneRepository {
  AdminDeliveryZoneRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminDeliveryZone>> loadZones() async {
    final rows = await _supabase
        .from('delivery_zones')
        .select()
        .order('name_en');
    return (rows as List)
        .whereType<Map>()
        .map(
          (row) => AdminDeliveryZone.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> loadZoneBranches() async {
    final rows = await _supabase.from('delivery_zone_branches').select();
    return (rows as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// Saves a zone within one branch's settings and binds it to that branch in
  /// the same database transaction. Shared zones are copied on edit so their
  /// geometry and price cannot unexpectedly affect a different branch.
  @override
  Future<AdminDeliveryZone> saveForBranch({
    required String branchId,
    required AdminDeliveryZone zone,
  }) async {
    final id = await _supabase.rpc(
      'admin_save_branch_delivery_zone',
      params: {
        'p_branch_id': branchId,
        'p_id': zone.id.isEmpty ? null : zone.id,
        'p_name_ar': zone.nameAr,
        'p_name_en': zone.nameEn,
        'p_delivery_fee': zone.deliveryFee,
        'p_min_order_amount': zone.minOrderAmount,
        'p_estimated_minutes': zone.estimatedMinutes,
        'p_center_latitude': zone.centerLatitude,
        'p_center_longitude': zone.centerLongitude,
        'p_radius_km': zone.radiusKm,
        'p_fee_method': zone.feeMethod,
        'p_fee_per_km': zone.feePerKm,
        'p_max_delivery_fee': zone.maxDeliveryFee,
        'p_free_delivery_over': zone.freeDeliveryOver,
        'p_is_active': zone.isActive,
      },
    );
    return zone.copyWith(id: '$id');
  }
}
