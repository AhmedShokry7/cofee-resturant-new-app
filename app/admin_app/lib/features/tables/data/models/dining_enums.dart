/// The part of the café a table belongs to.
enum DiningArea {
  hall('hall'),
  terrace('terrace'),
  privateRoom('private_room'),
  other('other');

  const DiningArea(this.value);

  final String value;

  static DiningArea fromValue(Object? value) {
    return switch ('$value') {
      'terrace' => DiningArea.terrace,
      'private_room' => DiningArea.privateRoom,
      'other' => DiningArea.other,
      _ => DiningArea.hall,
    };
  }
}

/// The live state of a table, derived by the server from orders and bookings.
enum DiningTableStatus {
  available('available'),
  reserved('reserved'),
  seated('seated'),
  occupied('occupied'),
  inactive('inactive');

  const DiningTableStatus(this.value);

  final String value;

  static DiningTableStatus fromValue(Object? value) {
    return switch ('$value') {
      'reserved' => DiningTableStatus.reserved,
      'seated' => DiningTableStatus.seated,
      'occupied' => DiningTableStatus.occupied,
      'inactive' => DiningTableStatus.inactive,
      _ => DiningTableStatus.available,
    };
  }
}

enum DiningReservationStatus {
  confirmed('confirmed'),
  seated('seated'),
  completed('completed'),
  cancelled('cancelled'),
  noShow('no_show');

  const DiningReservationStatus(this.value);

  final String value;

  bool get isOpen =>
      this == DiningReservationStatus.confirmed ||
      this == DiningReservationStatus.seated;

  bool get isClosed => !isOpen;

  static DiningReservationStatus fromValue(Object? value) {
    return switch ('$value') {
      'seated' => DiningReservationStatus.seated,
      'completed' => DiningReservationStatus.completed,
      'cancelled' => DiningReservationStatus.cancelled,
      'no_show' => DiningReservationStatus.noShow,
      _ => DiningReservationStatus.confirmed,
    };
  }
}
