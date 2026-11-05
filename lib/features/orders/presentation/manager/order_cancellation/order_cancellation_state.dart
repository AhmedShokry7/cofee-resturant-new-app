part of 'order_cancellation_cubit.dart';

@immutable
class OrderCancellationState {
  const OrderCancellationState({
    this.isCancelling = false,
    this.cancelled = false,
    this.error,
  });

  /// A cancellation is on its way, so the button cannot be pressed twice and put
  /// a second write on the server.
  final bool isCancelling;

  /// The server took the cancellation.
  final bool cancelled;

  /// A sentence the customer can read, never the provider's own text.
  final AppCopy? error;

  /// [error] as the sentence the customer reads, in their current language.
  String? get errorCopy => error?.copy;

  OrderCancellationState copyWith({
    bool? isCancelling,
    bool? cancelled,
    AppCopy? error,
    bool clearError = false,
  }) => OrderCancellationState(
    isCancelling: isCancelling ?? this.isCancelling,
    cancelled: cancelled ?? this.cancelled,
    error: clearError ? null : (error ?? this.error),
  );
}
