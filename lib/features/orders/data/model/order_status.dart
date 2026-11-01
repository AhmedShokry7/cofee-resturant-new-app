import 'package:new_coffee/core/locale/app_strings.dart';

enum OrderStatus {
  active,
  completed,
  cancelled;

  String get label => switch (this) {
    OrderStatus.active => S.orderStatusActive,
    OrderStatus.completed => S.orderStatusCompleted,
    OrderStatus.cancelled => S.orderStatusCancelled,
  };

  /// Maps the database status to the three customer-facing buckets.
  ///
  /// The Flutter list deliberately does not expose the operational detail
  /// (`pending` versus `confirmed` versus `preparing`); those are all "in
  /// progress" to a customer.
  static OrderStatus fromDatabase(String? value) {
    return switch (value) {
      'pending' ||
      'confirmed' ||
      'preparing' ||
      'ready' ||
      'out_for_delivery' => OrderStatus.active,
      'completed' => OrderStatus.completed,
      'cancelled' => OrderStatus.cancelled,
      _ => throw FormatException('Unknown order status: $value'),
    };
  }

  /// Database values that belong in this customer-facing bucket.
  static List<String> databaseValues(OrderStatus status) {
    return switch (status) {
      OrderStatus.active => const [
        'pending',
        'confirmed',
        'preparing',
        'ready',
        'out_for_delivery',
      ],
      OrderStatus.completed => const ['completed'],
      OrderStatus.cancelled => const ['cancelled'],
    };
  }
}
