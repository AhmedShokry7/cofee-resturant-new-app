part of 'orders_cubit.dart';

@immutable
class OrdersState {
  const OrdersState({
    required this.status,
    this.orders = const [],
    this.isLoading = true,
    this.error,
    this.signedOut = false,
  });

  final OrderStatus status;
  final List<OrderItemModel> orders;
  final bool isLoading;
  final String? error;

  /// True when there is no signed-in customer whose history could be read.
  final bool signedOut;

  /// The repository already filters by bucket, so this preserves the tab's
  /// order without reclassifying rows in the UI.
  List<OrderItemModel> get filtered => orders;

  /// Invoice lines grouped into orders, most recent first, so the list shows
  /// one card per order with its real header totals.
  List<OrderGroup> get grouped => OrderGroup.fromLines(orders);

  bool get isEmpty =>
      !isLoading && error == null && !signedOut && orders.isEmpty;

  OrdersState copyWith({
    OrderStatus? status,
    List<OrderItemModel>? orders,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? signedOut,
  }) => OrdersState(
    status: status ?? this.status,
    orders: orders ?? this.orders,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    signedOut: signedOut ?? this.signedOut,
  );
}
