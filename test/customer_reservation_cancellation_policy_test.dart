import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_event_request.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_reservation.dart';

void main() {
  group('customer cancellation policy response fields', () {
    test('reservation honors the server cutoff decision', () {
      final reservation = CustomerReservation.fromJson({
        'id': 'r-1',
        'branch_id': 'b-1',
        'status': 'confirmed',
        'source': 'customer',
        'reserved_for': '2026-12-01T10:00:00Z',
        'customer_can_cancel': false,
      });

      expect(reservation.customerCanCancel, isFalse);
    });

    test('confirmed event uses the server cutoff decision', () {
      final event = CustomerEventRequest.fromJson({
        'id': 'e-1',
        'occasion_type': 'birthday',
        'occasion_date': '2026-12-01',
        'preferred_start_at': '2026-12-01T10:00:00Z',
        'preferred_end_at': '2026-12-01T12:00:00Z',
        'guest_count': 4,
        'requested_space_type': 'table',
        'status': 'confirmed',
        'branch_name_ar': 'الفرع',
        'customer_can_cancel': false,
      });

      expect(event.customerCanCancel, isFalse);
    });

    test('older server responses keep the previous model default', () {
      final reservation = CustomerReservation.fromJson({
        'id': 'r-2',
        'branch_id': 'b-1',
        'status': 'pending',
        'source': 'customer',
        'reserved_for': '2026-12-01T10:00:00Z',
      });

      expect(reservation.customerCanCancel, isTrue);
    });
  });
}
