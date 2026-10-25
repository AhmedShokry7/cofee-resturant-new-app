import 'package:flutter/foundation.dart';

@immutable
class OrderFilterValues {
  const OrderFilterValues({
    this.status = '',
    this.fulfillment = '',
    this.paymentStatus = '',
    this.branchId = '',
  });
  final String status, fulfillment, paymentStatus, branchId;
  bool get isActive =>
      status.isNotEmpty ||
      fulfillment.isNotEmpty ||
      paymentStatus.isNotEmpty ||
      branchId.isNotEmpty;

  OrderFilterValues copyWith({
    String? status,
    String? fulfillment,
    String? paymentStatus,
    String? branchId,
  }) => OrderFilterValues(
    status: status ?? this.status,
    fulfillment: fulfillment ?? this.fulfillment,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    branchId: branchId ?? this.branchId,
  );
}
