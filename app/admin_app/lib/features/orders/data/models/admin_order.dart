import 'package:admin_app/core/locale/app_locale.dart';

class AdminOrderItem {
  const AdminOrderItem({
    this.id,
    this.productId,
    this.productNameAr,
    this.productNameEn,
    this.imageUrl,
    this.note,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String? id;
  final String? productId;
  final String? productNameAr;
  final String? productNameEn;
  final String? imageUrl;
  final String? note;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  String productNameFor(AppLanguage language) {
    if (language.isArabic &&
        productNameAr != null &&
        productNameAr!.trim().isNotEmpty) {
      return productNameAr!.trim();
    }
    if (!language.isArabic &&
        productNameEn != null &&
        productNameEn!.trim().isNotEmpty) {
      return productNameEn!.trim();
    }
    return 'Product';
  }

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) {
    return AdminOrderItem(
      id: json['id'] as String?,
      productId: json['product_id'] as String?,
      productNameAr: json['product_name_ar'] as String?,
      productNameEn: json['product_name_en'] as String?,
      imageUrl: (json['image_url'] ?? json['image_snapshot']) as String?,
      note: json['note'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

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

  final String id;
  final String orderNumber;
  final String? userId;
  final String? customerName;
  final String? customerEmail;
  final String? customerAvatarUrl;
  final String? customerPhone;
  final String? branchId;
  final String? paymentMethodId;
  final String? branchNameAr;
  final String? branchNameEn;
  final double? branchLatitude;
  final double? branchLongitude;
  final Map<String, dynamic>? deliveryAddressSnapshot;
  final String fulfillmentType;
  final String status;
  final String paymentStatus;
  final double subtotal;
  final double discountTotal;
  final double deliveryFee;
  final double taxTotal;
  final double grandTotal;
  final DateTime? placedAt;
  final List<AdminOrderItem> items;

  AdminOrder copyWith({
    String? status,
    String? paymentStatus,
  }) {
    return AdminOrder(
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

  String branchNameFor(AppLanguage language) {
    if (language.isArabic) return branchNameAr?.trim() ?? '';
    return branchNameEn?.trim() ?? '';
  }

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>?;
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
      deliveryAddressSnapshot: json['delivery_address_snapshot'] is Map
          ? Map<String, dynamic>.from(json['delivery_address_snapshot'] as Map)
          : null,
      fulfillmentType: '${json['fulfillment_type'] ?? ''}',
      status: '${json['status'] ?? ''}',
      paymentStatus: '${json['payment_status'] ?? ''}',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discountTotal: (json['discount_total'] as num?)?.toDouble() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      taxTotal: (json['tax_total'] as num?)?.toDouble() ?? 0,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0,
      placedAt: _toDateTime(json['placed_at']),
      items:
          itemsRaw
              ?.map(
                (e) => AdminOrderItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <AdminOrderItem>[],
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
