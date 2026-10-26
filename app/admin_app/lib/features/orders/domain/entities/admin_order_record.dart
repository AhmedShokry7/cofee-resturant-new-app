import 'admin_order_item.dart';
import 'admin_order_json.dart';

class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.orderNumber,
    this.userId,
    this.customerName,
    this.customerEmail,
    this.customerAvatarUrl,
    this.customerPhone,
    this.branchId,
    this.paymentMethodId,
    this.branchNameAr,
    this.branchNameEn,
    this.branchLatitude,
    this.branchLongitude,
    this.deliveryAddressSnapshot,
    required this.fulfillmentType,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.discountTotal,
    required this.deliveryFee,
    required this.taxTotal,
    required this.grandTotal,
    this.placedAt,
    this.items = const <AdminOrderItem>[],
  });

  final String id, orderNumber;
  final String? userId, customerName, customerEmail, customerAvatarUrl;
  final String? customerPhone, branchId, paymentMethodId, branchNameAr;
  final String? branchNameEn;
  final double? branchLatitude, branchLongitude;
  final Map<String, dynamic>? deliveryAddressSnapshot;
  final String fulfillmentType, status, paymentStatus;
  final double subtotal, discountTotal, deliveryFee, taxTotal, grandTotal;
  final DateTime? placedAt;
  final List<AdminOrderItem> items;

  factory AdminOrder.fromJson(Map<String, dynamic> json) =>
      AdminOrderJson.parse(json);
}
