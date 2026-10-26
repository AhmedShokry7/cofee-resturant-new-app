import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_reservation.dart';

/// The open order sitting on a table right now.
class DiningActiveOrder {
  const DiningActiveOrder({
    required this.id,
    required this.orderNumber,
    this.status = '',
    this.grandTotal = 0,
    this.placedAt,
    this.reservationId,
  });

  final String id;
  final String orderNumber;
  final String status;
  final double grandTotal;
  final DateTime? placedAt;
  final String? reservationId;

  factory DiningActiveOrder.fromJson(Map<String, dynamic> json) {
    return DiningActiveOrder(
      id: _text(json['id']),
      orderNumber: _text(json['order_number']),
      status: _text(json['status']),
      grandTotal: _number(json['grand_total']),
      placedAt: _date(json['placed_at']),
      reservationId: _textOrNull(json['reservation_id']),
    );
  }
}

/// One dining table or private room on the floor plan.
class DiningTable {
  const DiningTable({
    required this.id,
    required this.branchId,
    required this.name,
    this.area = DiningArea.hall,
    this.capacity = 2,
    this.isActive = true,
    this.sortOrder = 0,
    this.note = '',
    this.status = DiningTableStatus.available,
    this.activeOrder,
    this.reservation,
    this.nextReservation,
  });

  final String id;
  final String branchId;
  final String name;
  final DiningArea area;
  final int capacity;
  final bool isActive;
  final int sortOrder;
  final String note;
  final DiningTableStatus status;
  final DiningActiveOrder? activeOrder;

  /// The booking that currently holds the table (seated, or arriving within
  /// the next half hour).
  final DiningReservation? reservation;

  /// The next confirmed booking after [reservation], if any.
  final DiningReservation? nextReservation;

  bool get isSelectable => status == DiningTableStatus.available;

  bool get hasOrder => activeOrder != null;

  factory DiningTable.fromJson(Map<String, dynamic> json) {
    final branchId = _text(json['branch_id']);
    final name = _text(json['name']);
    return DiningTable(
      id: _text(json['id']),
      branchId: branchId,
      name: name,
      area: DiningArea.fromValue(json['area']),
      capacity: _integer(json['capacity'], fallback: 2),
      isActive: _flag(json['is_active'], fallback: true),
      sortOrder: _integer(json['sort_order']),
      note: _text(json['note']),
      status: DiningTableStatus.fromValue(json['status']),
      activeOrder: _mapOrNull(json['active_order'], DiningActiveOrder.fromJson),
      reservation: _mapOrNull(
        json['reservation'],
        (map) => DiningReservation.fromJson(
          map,
          branchId: branchId,
          tableId: _text(json['id']),
          tableName: name,
        ),
      ),
      nextReservation: _mapOrNull(
        json['next_reservation'],
        (map) => DiningReservation.fromJson(
          map,
          branchId: branchId,
          tableId: _text(json['id']),
          tableName: name,
        ),
      ),
    );
  }
}

T? _mapOrNull<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! Map) return null;
  return parse(Map<String, dynamic>.from(value));
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

double _number(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? fallback;
}

bool _flag(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  final text = '$value'.toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return fallback;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
