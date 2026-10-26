import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/pos/data/models/pos_table.dart';
import 'package:admin_app/features/tables/data/models/dining_enums.dart';
import 'package:admin_app/features/tables/data/models/dining_overview.dart';
import 'package:admin_app/features/tables/data/models/dining_reservation.dart';
import 'package:admin_app/features/tables/data/models/dining_table.dart';

DiningTable _table({
  DiningTableStatus status = DiningTableStatus.available,
  DiningReservationStatus reservationStatus = DiningReservationStatus.confirmed,
  DateTime? reservedFor,
}) {
  return DiningTable(
    id: 't-1',
    branchId: 'b1',
    name: 'طاولة 1',
    status: status,
    reservation: DiningReservation(
      id: 'r-1',
      customerName: 'سارة',
      reservedFor:
          reservedFor ?? DateTime.now().add(const Duration(minutes: 20)),
      status: reservationStatus,
    ),
  );
}

void main() {
  test('the dining overview reads the live floor and its metrics', () {
    final soon = DateTime.now().add(const Duration(minutes: 25)).toUtc();
    final overview = DiningOverview.fromJson({
      'branch_id': 'b1',
      'branches': [
        {'id': 'b1', 'code': 'MAADI', 'name_ar': 'المعادي', 'name_en': 'Maadi'},
        {
          'id': 'b2',
          'code': 'NASR',
          'name_ar': 'مدينة نصر',
          'is_active': false,
        },
      ],
      'tables': [
        {
          'id': 't-1',
          'branch_id': 'b1',
          'name': 'طاولة 1',
          'area': 'terrace',
          'capacity': 4,
          'status': 'occupied',
          'active_order': {
            'id': 'o-1',
            'order_number': 'POS-2026-000042',
            'status': 'preparing',
            'grand_total': 42.5,
          },
        },
        {
          'id': 't-2',
          'branch_id': 'b1',
          'name': 'غرفة 2',
          'area': 'private_room',
          'capacity': 6,
          'status': 'reserved',
          'reservation': {
            'id': 'r-1',
            'customer_name': 'سارة',
            'customer_phone': '01000000000',
            'party_size': 5,
            'reserved_for': soon.toIso8601String(),
            'duration_minutes': 120,
            'status': 'confirmed',
          },
        },
      ],
      'reservations': [
        {
          'id': 'r-1',
          'table_id': 't-2',
          'table_name': 'غرفة 2',
          'customer_name': 'سارة',
          'party_size': 5,
          'reserved_for': soon.toIso8601String(),
          'status': 'seated',
        },
      ],
      'metrics': {
        'tables': 2,
        'available': 0,
        'occupied': 1,
        'reserved': 1,
        'reservations_today': 3,
        'upcoming': 1,
      },
    });

    expect(overview.branchId, 'b1');
    expect(overview.branches, hasLength(2));
    expect(overview.branches.last.isActive, isFalse);
    expect(overview.tables, hasLength(2));

    final busy = overview.tables.first;
    expect(busy.area, DiningArea.terrace);
    expect(busy.capacity, 4);
    expect(busy.status, DiningTableStatus.occupied);
    expect(busy.activeOrder?.orderNumber, 'POS-2026-000042');
    expect(busy.activeOrder?.grandTotal, 42.5);
    expect(busy.isPosSelectable, isFalse);
    expect(busy.hasOpenOrder, isTrue);

    final booked = overview.tables.last;
    expect(booked.area, DiningArea.privateRoom);
    expect(booked.status, DiningTableStatus.reserved);
    expect(booked.reservation?.customerName, 'سارة');
    expect(booked.reservation?.tableId, 't-2');
    expect(booked.reservation?.partySize, 5);
    expect(booked.reservation?.durationMinutes, 120);
    expect(booked.isPosSelectable, isFalse);
    expect(booked.canSeatGuest, isTrue);

    expect(overview.reservations.single.status, DiningReservationStatus.seated);
    expect(overview.reservations.single.isOpen, isTrue);
    expect(overview.metrics.tables, 2);
    expect(overview.metrics.occupied, 1);
    expect(overview.metrics.reserved, 1);
    expect(overview.metrics.reservationsToday, 3);
    expect(overview.metrics.upcoming, 1);
  });

  test('unknown statuses and areas fall back to safe defaults', () {
    final table = DiningTable.fromJson({'id': 't-9', 'name': 'طاولة 9'});

    expect(table.status, DiningTableStatus.available);
    expect(table.area, DiningArea.hall);
    expect(table.capacity, 2);
    expect(table.isActive, isTrue);
    expect(table.activeOrder, isNull);
    expect(table.reservation, isNull);
    expect(table.isPosSelectable, isTrue);
    expect(table.canSeatGuest, isFalse);

    final overview = DiningOverview.fromJson(const <String, dynamic>{});
    expect(overview.branchId, isNull);
    expect(overview.branches, isEmpty);
    expect(overview.metrics.tables, 0);
  });

  test('only available and seated tables can take a counter order', () {
    expect(_table().isPosSelectable, isTrue);
    expect(_table(status: DiningTableStatus.seated).isPosSelectable, isTrue);
    expect(_table(status: DiningTableStatus.reserved).isPosSelectable, isFalse);
    expect(_table(status: DiningTableStatus.occupied).isPosSelectable, isFalse);
    expect(_table(status: DiningTableStatus.inactive).isPosSelectable, isFalse);
  });

  test('a booking is seatable only while it is confirmed', () {
    expect(_table(status: DiningTableStatus.reserved).canSeatGuest, isTrue);
    expect(
      _table(
        status: DiningTableStatus.reserved,
        reservationStatus: DiningReservationStatus.seated,
      ).canSeatGuest,
      isFalse,
    );
    expect(
      _table(
        status: DiningTableStatus.reserved,
        reservationStatus: DiningReservationStatus.cancelled,
      ).canSeatGuest,
      isFalse,
    );
    expect(_table(status: DiningTableStatus.available).canSeatGuest, isFalse);
  });

  test('a booking is current only near its start and while seated', () {
    final now = DateTime.now();
    final arriving = _table(reservedFor: now.add(const Duration(minutes: 15)))
        .reservation!;
    expect(arriving.isCurrentAt(now), isTrue);

    final later = _table(reservedFor: now.add(const Duration(hours: 5)))
        .reservation!;
    expect(later.isCurrentAt(now), isFalse);

    final ended = _table(reservedFor: now.subtract(const Duration(hours: 3)))
        .reservation!;
    expect(ended.isCurrentAt(now), isFalse);

    final seated = _table(
      status: DiningTableStatus.seated,
      reservationStatus: DiningReservationStatus.seated,
      reservedFor: now.subtract(const Duration(hours: 3)),
    ).reservation!;
    expect(seated.isCurrentAt(now), isTrue);

    final cancelled = _table(
      reservationStatus: DiningReservationStatus.cancelled,
    ).reservation!;
    expect(cancelled.isCurrentAt(now), isFalse);
    expect(cancelled.isClosed, isTrue);
  });
}
