import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_table.dart';

/// Floor rules the counter applies on top of the server's table status.
extension PosDiningTable on DiningTable {
  /// A free table, or a table whose booked guest is already seated and still
  /// needs a counter order.
  bool get isPosSelectable =>
      status == DiningTableStatus.available ||
      status == DiningTableStatus.seated;

  /// A confirmed booking the cashier can mark as seated from the counter.
  bool get canSeatGuest =>
      status == DiningTableStatus.reserved &&
      reservation?.status == DiningReservationStatus.confirmed;

  bool get hasOpenOrder => status == DiningTableStatus.occupied;
}
