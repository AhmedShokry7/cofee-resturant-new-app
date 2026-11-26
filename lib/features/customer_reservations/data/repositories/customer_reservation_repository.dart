import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_reservation.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_event_request.dart';

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
    return list
        .whereType<Map>()
        .map((e) => CustomerReservation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
    final durationMinutes = requestedEndAt?.difference(reservedFor).inMinutes;
    if (durationMinutes != null &&
        (durationMinutes < 30 || durationMinutes > 480)) {
      throw ArgumentError(
        'Reservation duration must be between 30 and 480 minutes.',
      );
    }
    await _db.rpc(
      'create_customer_reservation',
      params: {
        'p_payload': {
          'branch_id': branchId,
          'reserved_for': reservedFor.toUtc().toIso8601String(),
          'duration_minutes': ?durationMinutes,
          'party_size': partySize,
          'note': note,
          'table_id': tableId,
          'reservation_type': reservationType,
        },
      },
    );
  }

  Future<void> cancel(String id) async {
    await _db.rpc('cancel_my_reservation', params: {'p_id': id});
  }

  Future<List<CustomerEventRequest>> listMyEventRequests() async {
    final result = await _db.rpc('list_my_customer_event_requests');
    return (result as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) =>
              CustomerEventRequest.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<void> createEventRequest({
    required String branchId,
    required String occasionType,
    String? occasionName,
    required DateTime startAt,
    required DateTime endAt,
    required int guestCount,
    required String spaceType,
    String? services,
    String? note,
    double? estimatedBudget,
    int reminderMinutes = 1440,
  }) async {
    await _db.rpc(
      'create_my_customer_event_request',
      params: {
        'p_payload': {
          'branch_id': branchId,
          'occasion_type': occasionType,
          if (occasionName != null && occasionName.trim().isNotEmpty)
            'occasion_name': occasionName.trim(),
          'preferred_start_at': startAt.toUtc().toIso8601String(),
          'preferred_end_at': endAt.toUtc().toIso8601String(),
          'guest_count': guestCount,
          'requested_space_type': spaceType,
          'reminder_minutes': reminderMinutes,
          if (services != null && services.trim().isNotEmpty)
            'requested_services': services.trim(),
          if (note != null && note.trim().isNotEmpty)
            'customer_note': note.trim(),
          'estimated_budget': ?estimatedBudget,
        },
      },
    );
  }

  Future<List<CustomerEventRequest>> listMyUpcomingEventReminders() async {
    final result = await _db.rpc('list_my_event_reminders');
    return (result as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) =>
              CustomerEventRequest.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<bool> cancelEventRequest(String id) async =>
      await _db.rpc('cancel_my_customer_event_request', params: {'p_id': id}) ==
      true;

  Future<Map<String, dynamic>> respondToEventQuote(
    String id, {
    required bool accept,
    String? spaceId,
  }) async {
    final result = await _db.rpc(
      'respond_my_customer_event_quote',
      params: {'p_id': id, 'p_accept': accept, 'p_space_id': spaceId},
    );
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }
}
