import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/checkout/data/repositories/pickup_schedule_repository.dart';

void main() {
  test('loads only server-returned days with branch-local dates', () async {
    String? called;
    Map<String, dynamic>? params;
    final repository = PickupScheduleRepository(
      rpc: (name, arguments) async {
        called = name;
        params = arguments;
        return [
          {'service_date': '2026-11-27'},
          {'service_date': '2026-11-29'},
        ];
      },
    );

    final days = await repository.availableDays('branch-1', DateTime(2026, 11, 27));

    expect(called, 'available_pickup_days');
    expect(params?['p_branch'], 'branch-1');
    expect(days, [DateTime(2026, 11, 27), DateTime(2026, 11, 29)]);
  });

  test('parses server slot capacity and instant without inventing slots', () async {
    final repository = PickupScheduleRepository(
      rpc: (name, params) async => [
        {'slot_start': '2026-11-27T08:00:00Z', 'remaining': 2},
      ],
    );

    final slots = await repository.available('branch-1', DateTime(2026, 11, 27));

    expect(slots, hasLength(1));
    expect(slots.single.startsAt.toUtc(), DateTime.utc(2026, 11, 27, 8));
    expect(slots.single.remaining, 2);
  });
}
