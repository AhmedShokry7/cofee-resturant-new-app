import 'package:admin_app/core/models/dining_reservation.dart';

/// The editable fields of a booking.
class DiningReservationDraft {
  const DiningReservationDraft({
    this.id,
    required this.tableId,
    required this.customerName,
    this.customerPhone = '',
    this.partySize = 2,
    required this.reservedFor,
    this.durationMinutes = 90,
    this.note = '',
  });

  final String? id;
  final String tableId;
  final String customerName;
  final String customerPhone;
  final int partySize;
  final DateTime reservedFor;
  final int durationMinutes;
  final String note;

  Map<String, Object?> toJson() {
    return {
      if (id != null) 'id': id,
      'table_id': tableId,
      'customer_name': customerName.trim(),
      'customer_phone': customerPhone.trim(),
      'party_size': partySize,
      'reserved_for': reservedFor.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'note': note.trim(),
    };
  }

  factory DiningReservationDraft.fromReservation(
    DiningReservation reservation,
  ) {
    return DiningReservationDraft(
      id: reservation.id,
      tableId: reservation.tableId,
      customerName: reservation.customerName,
      customerPhone: reservation.customerPhone,
      partySize: reservation.partySize,
      reservedFor:
          reservation.reservedFor ??
          DateTime.now().add(const Duration(hours: 1)),
      durationMinutes: reservation.durationMinutes,
      note: reservation.note,
    );
  }
}
