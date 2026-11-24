import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_reservation.dart';

class CustomerReservationRepository {
  CustomerReservationRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;
  final SupabaseClient? _client;
  SupabaseClient get _db {
    final c = _client;
    if (c == null) throw StateError('Supabase client unavailable');
    return c;
  }

  Future<List<CustomerReservation>> listMine() async {
    final res = await _db.rpc('list_my_reservations');
    final list = (res as List?) ?? const [];
    return list.whereType<Map>().map((e) => CustomerReservation.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> create({
    required String branchId,
    required DateTime reservedFor,
    DateTime? requestedEndAt,
    int? partySize,
    String? note,
    String? tableId,
    String reservationType = 'table',
  }) async {
    await _db.rpc('create_customer_reservation', params: {
      'p_payload': {
        'branch_id': branchId,
        'reserved_for': reservedFor.toUtc().toIso8601String(),
        'requested_end_at': requestedEndAt?.toUtc().toIso8601String(),
        'party_size': partySize,
        'note': note,
        'table_id': tableId,
        'reservation_type': reservationType,
      }
    });
  }

  Future<void> cancel(String id) async {
    await _db.rpc('cancel_my_reservation', params: {'p_id': id});
  }
}
