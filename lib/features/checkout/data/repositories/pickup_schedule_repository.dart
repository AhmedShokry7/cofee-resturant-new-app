import 'package:new_coffee/core/services/supabase_service.dart';

class PickupSlot {
  const PickupSlot(this.startsAt, this.remaining);
  final DateTime startsAt;
  final int remaining;
  factory PickupSlot.fromJson(Map<String, dynamic> row) => PickupSlot(
    DateTime.parse(row['slot_start'].toString()).toLocal(),
    (row['remaining'] as num).toInt(),
  );
}

class PickupScheduleRepository {
  const PickupScheduleRepository({this.rpc});

  final Future<dynamic> Function(String name, Map<String, dynamic> params)? rpc;

  Future<dynamic> _call(String name, Map<String, dynamic> params) =>
      rpc == null ? SupabaseService.client.rpc(name, params: params) : rpc!(name, params);

  Future<List<DateTime>> availableDays(String branchId, DateTime start) async {
    final rows = await _call('available_pickup_days', {
      'p_branch': branchId,
      'p_start': '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      'p_days': 14,
    });
    return (rows as List).map((row) {
      final parts = '${(row as Map)['service_date']}'.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toList(growable: false);
  }

  Future<List<PickupSlot>> available(String branchId, DateTime date) async {
    final rows = await _call('available_pickup_slots', {
      'p_branch': branchId,
      'p_date': '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}',
    });
    return (rows as List).map((row) => PickupSlot.fromJson(Map<String,dynamic>.from(row as Map))).toList(growable: false);
  }
}
