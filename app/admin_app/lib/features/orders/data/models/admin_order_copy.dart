import 'admin_order_record.dart';

extension AdminOrderCopy on AdminOrder {
  AdminOrder copyWith({String? status, String? paymentStatus}) => AdminOrder(
    id: id,
    orderNumber: orderNumber,
    userId: userId,
    customerName: customerName,
    customerEmail: customerEmail,
    customerAvatarUrl: customerAvatarUrl,
    customerPhone: customerPhone,
    branchId: branchId,
    paymentMethodId: paymentMethodId,
    branchNameAr: branchNameAr,
    branchNameEn: branchNameEn,
    branchLatitude: branchLatitude,
    branchLongitude: branchLongitude,
    deliveryAddressSnapshot: deliveryAddressSnapshot,
    fulfillmentType: fulfillmentType,
    status: status ?? this.status,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    subtotal: subtotal,
    discountTotal: discountTotal,
    deliveryFee: deliveryFee,
    taxTotal: taxTotal,
    grandTotal: grandTotal,
    placedAt: placedAt,
    items: items,
  );
}
