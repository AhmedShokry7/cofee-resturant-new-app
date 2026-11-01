part of 'order_tracking_cubit.dart';

@immutable
class OrderTrackingState {
  const OrderTrackingState({
    this.events,
    this.isLoading = true,
    this.failed = false,
  });

  /// The status changes, null until they arrive so an order that has none is
  /// not mistaken for one that is still loading.
  final List<OrderStatusEvent>? events;

  final bool isLoading;

  /// The read failed; the screen says so and offers a retry.
  final bool failed;

  OrderTrackingState copyWith({
    List<OrderStatusEvent>? events,
    bool? isLoading,
    bool? failed,
    bool clearEvents = false,
  }) => OrderTrackingState(
    events: clearEvents ? null : (events ?? this.events),
    isLoading: isLoading ?? this.isLoading,
    failed: failed ?? this.failed,
  );
}
