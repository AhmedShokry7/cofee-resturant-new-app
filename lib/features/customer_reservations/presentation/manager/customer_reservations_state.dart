import 'package:new_coffee/features/customer_reservations/data/model/customer_reservation.dart';

enum CustomerReservationsStatus { initial, loading, loaded, failure }

class CustomerReservationsState {
  const CustomerReservationsState({this.status = CustomerReservationsStatus.initial, this.items = const [], this.error});
  final CustomerReservationsStatus status;
  final List<CustomerReservation> items;
  final String? error;
  CustomerReservationsState copyWith({CustomerReservationsStatus? status, List<CustomerReservation>? items, String? error}) =>
      CustomerReservationsState(status: status ?? this.status, items: items ?? this.items, error: error);
}
