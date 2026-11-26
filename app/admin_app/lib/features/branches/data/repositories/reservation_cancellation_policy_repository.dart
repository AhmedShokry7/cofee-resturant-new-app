import 'package:admin_app/core/services/supabase_service.dart';

class ReservationCancellationPolicyRepository {
  Future<Map<String, dynamic>> load(String branchId) async {
    final result = await SupabaseService.client.rpc(
      'admin_get_reservation_cancellation_policy',
      params: {'p_branch_id': branchId},
    );
    if (result is! Map || result['ok'] != true) {
      throw StateError('Cancellation policy unavailable');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<void> save(String branchId, int tableMinutes, int eventMinutes) async {
    final result = await SupabaseService.client.rpc(
      'admin_set_reservation_cancellation_policy',
      params: {
        'p_branch_id': branchId,
        'p_table_cutoff_minutes': tableMinutes,
        'p_event_cutoff_minutes': eventMinutes,
      },
    );
    if (result is! Map || result['ok'] != true) {
      throw StateError('Cancellation policy save failed');
    }
  }
}
