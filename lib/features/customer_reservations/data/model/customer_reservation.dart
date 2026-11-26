import 'package:new_coffee/core/data/db_values.dart';

class CustomerReservation {
  const CustomerReservation({
    required this.id,
    required this.branchId,
    this.tableId,
    required this.status,
    required this.source,
    required this.reservedFor,
    this.requestedEndAt,
    this.reservedUntil,
    this.partySize,
    this.customerNote,
    this.adminNote,
    this.cancellationReason,
    this.reservationType = 'table',
    this.createdAt,
  });

  final String id;
  final String branchId;
  final String? tableId;
  final String status;
  final String source;
  final DateTime reservedFor;
  final DateTime? requestedEndAt;
  final DateTime? reservedUntil;
  final int? partySize;
  final String? customerNote;
  final String? adminNote;
  final String? cancellationReason;
  final String reservationType;
  final DateTime? createdAt;

  factory CustomerReservation.fromJson(Map<String, dynamic> json) {
    return CustomerReservation(
      id: Db.text(json['id']),
      branchId: Db.text(json['branch_id']),
      tableId: Db.textOrNull(json['table_id']),
      status: Db.text(json['status'], 'pending'),
      source: Db.text(json['source'], 'customer'),
      reservedFor: Db.asDateTime(json['reserved_for']),
      requestedEndAt: Db.asDateTimeOrNull(json['requested_end_at']),
      reservedUntil: Db.asDateTimeOrNull(json['reserved_until']),
      partySize: json['party_size'] == null ? null : Db.asInt(json['party_size']),
      customerNote: Db.textOrNull(json['customer_note'] ?? json['note']),
      adminNote: Db.textOrNull(json['admin_note']),
      cancellationReason: Db.textOrNull(json['cancellation_reason']),
      reservationType: Db.text(json['reservation_type'], 'table'),
      createdAt: Db.asDateTimeOrNull(json['created_at']),
    );
  }
}
