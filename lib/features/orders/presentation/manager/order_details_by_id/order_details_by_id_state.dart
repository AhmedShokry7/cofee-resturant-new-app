part of 'order_details_by_id_cubit.dart';

@immutable
class OrderDetailsByIdState {
  const OrderDetailsByIdState({
    this.isLoading = true,
    this.order,
    this.notFound = false,
    this.signedOut = false,
    this.error,
  });

  final bool isLoading;

  /// The order and its frozen lines, once they have been read.
  final OrderGroup? order;

  /// The backend answered and the id is not one of this customer's orders: it
  /// was deleted, or the message names a record that is not theirs.
  final bool notFound;
  final bool signedOut;
  final String? error;

  OrderDetailsByIdState copyWith({
    bool? isLoading,
    OrderGroup? order,
    bool? notFound,
    bool? signedOut,
    String? error,
    bool clearError = false,
  }) {
    return OrderDetailsByIdState(
      isLoading: isLoading ?? this.isLoading,
      order: order ?? this.order,
      notFound: notFound ?? this.notFound,
      signedOut: signedOut ?? this.signedOut,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
