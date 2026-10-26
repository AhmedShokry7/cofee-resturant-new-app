import 'admin_order_item.dart';
import 'admin_order_record.dart';

class AdminOrderJson {
  static AdminOrder parse(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return AdminOrder(
      id: '${json['id'] ?? ''}',
      orderNumber: '${json['order_number'] ?? ''}',
      userId: json['user_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      customerAvatarUrl: json['customer_avatar_url'] as String?,
      customerPhone: json['customer_phone'] as String?,
      branchId: json['branch_id'] as String?,
      paymentMethodId: json['payment_method_id'] as String?,
      branchNameAr: json['branch_name_ar'] as String?,
      branchNameEn: json['branch_name_en'] as String?,
      branchLatitude: (json['branch_latitude'] as num?)?.toDouble(),
      branchLongitude: (json['branch_longitude'] as num?)?.toDouble(),
      deliveryAddressSnapshot: _map(json['delivery_address_snapshot']),
      fulfillmentType: '${json['fulfillment_type'] ?? ''}',
      status: '${json['status'] ?? ''}',
      paymentStatus: '${json['payment_status'] ?? ''}',
      subtotal: _number(json['subtotal']),
      discountTotal: _number(json['discount_total']),
      deliveryFee: _number(json['delivery_fee']),
      taxTotal: _number(json['tax_total']),
      grandTotal: _number(json['grand_total']),
      placedAt: DateTime.tryParse('${json['placed_at'] ?? ''}'),
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => AdminOrderItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static double _number(Object? value) => value is num ? value.toDouble() : 0;
}
