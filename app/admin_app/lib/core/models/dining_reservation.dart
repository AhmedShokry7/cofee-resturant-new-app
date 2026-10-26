import 'package:admin_app/core/models/dining_enums.dart';

/// A guest booking for a table or private room.
class DiningReservation {
  const DiningReservation({
    required this.id,
    this.branchId = '',
    this.tableId = '',
    this.tableName = '',
    this.area = DiningArea.hall,
    required this.customerName,
    this.customerPhone = '',
    this.partySize = 1,
    this.reservedFor,
    this.durationMinutes = 90,
    this.status = DiningReservationStatus.confirmed,
    this.note = '',
    this.orderId,
    this.createdAt,
  });

  final String id;
  final String branchId;
  final String tableId;
  final String tableName;
  final DiningArea area;
  final String customerName;
  final String customerPhone;
  final int partySize;
  final DateTime? reservedFor;
  final int durationMinutes;
  final DiningReservationStatus status;
  final String note;
  final String? orderId;
  final DateTime? createdAt;

  bool get isOpen => status.isOpen;

  bool get isClosed => status.isClosed;

  bool get hasOrder => (orderId ?? '').isNotEmpty;

  DateTime? get endsAt {
    final start = reservedFor;
    if (start == null) return null;
    return start.add(Duration(minutes: durationMinutes));
  }

  /// True while the guest is expected to be at the table: they are seated, or
  /// the booking starts within the next half hour and has not ended yet.
  bool isCurrentAt(DateTime now) {
    if (status == DiningReservationStatus.seated) return true;
    final start = reservedFor;
    if (start == null || status != DiningReservationStatus.confirmed) {
      return false;
    }
    final end = start.add(Duration(minutes: durationMinutes));
    return !start.isAfter(now.add(const Duration(minutes: 30))) &&
        end.isAfter(now);
  }

  factory DiningReservation.fromJson(
    Map<String, dynamic> json, {
    String branchId = '',
    String tableId = '',
    String tableName = '',
  }) {
    return DiningReservation(
      id: _text(json['id']),
      branchId: _text(json['branch_id']).isEmpty
          ? branchId
          : _text(json['branch_id']),
      tableId: _text(json['table_id']).isEmpty
          ? tableId
          : _text(json['table_id']),
      tableName: _text(json['table_name']).isEmpty
          ? tableName
          : _text(json['table_name']),
      area: DiningArea.fromValue(json['area']),
      customerName: _text(json['customer_name']),
      customerPhone: _text(json['customer_phone']),
      partySize: _integer(json['party_size'], fallback: 1),
      reservedFor: _date(json['reserved_for']),
      durationMinutes: _integer(json['duration_minutes'], fallback: 90),
      status: DiningReservationStatus.fromValue(json['status']),
      note: _text(json['note']),
      orderId: _textOrNull(json['order_id']),
      createdAt: _date(json['created_at']),
    );
  }
}

String _text(Object? value) => value == null ? '' : '$value'.trim();

String? _textOrNull(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

int _integer(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
