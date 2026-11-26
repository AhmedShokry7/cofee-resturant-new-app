import 'package:new_coffee/features/customer_reservations/data/model/customer_reservation.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_event_request.dart';

enum CustomerReservationsStatus { initial, loading, loaded, failure }

class CustomerReservationsState {
  const CustomerReservationsState({
    this.status = CustomerReservationsStatus.initial,
    this.items = const [],
    this.eventRequests = const [],
    this.error,
  });
  final CustomerReservationsStatus status;
  final List<CustomerReservation> items;
  final List<CustomerEventRequest> eventRequests;
  final String? error;
  CustomerReservationsState copyWith({
    CustomerReservationsStatus? status,
    List<CustomerReservation>? items,
    List<CustomerEventRequest>? eventRequests,
    String? error,
    bool clearError = false,
  }) => CustomerReservationsState(
    status: status ?? this.status,
    items: items ?? this.items,
    eventRequests: eventRequests ?? this.eventRequests,
    error: clearError ? null : (error ?? this.error),
  );
}
