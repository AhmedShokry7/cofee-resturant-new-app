import 'package:admin_app/core/locale/app_locale.dart';

class AdminCartItem {
  const AdminCartItem({
    required this.id,
    required this.productId,
    this.productNameAr,
    this.productNameEn,
    this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.note = '',
  });

  final String id;
  final String productId;
  final String? productNameAr;
  final String? productNameEn;
  final String? imageUrl;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String note;

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
    return productId;
  }

  factory AdminCartItem.fromJson(Map<String, dynamic> json) {
    return AdminCartItem(
      id: '${json['id'] ?? ''}',
      productId: '${json['product_id'] ?? ''}',
      productNameAr: json['product_name_ar'] as String?,
      productNameEn: json['product_name_en'] as String?,
      imageUrl: json['image_url'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      note: '${json['note'] ?? ''}',
    );
  }
}

class AdminCart {
  const AdminCart({
    required this.id,
    this.userId,
    this.customerName,
    this.customerEmail,
    this.branchId,
    this.branchNameAr,
    this.branchNameEn,
    required this.status,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
    required this.total,
    this.items = const <AdminCartItem>[],
  });

  final String id;
  final String? userId;
  final String? customerName;
  final String? customerEmail;
  final String? branchId;
  final String? branchNameAr;
  final String? branchNameEn;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double total;
  final List<AdminCartItem> items;

  String branchNameFor(AppLanguage language) {
    if (language.isArabic) return branchNameAr?.trim() ?? '';
    return branchNameEn?.trim() ?? '';
  }

  factory AdminCart.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>?;
    return AdminCart(
      id: '${json['id'] ?? ''}',
      userId: json['user_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      branchId: json['branch_id'] as String?,
      branchNameAr: json['branch_name_ar'] as String?,
      branchNameEn: json['branch_name_en'] as String?,
      status: '${json['status'] ?? ''}',
      expiresAt: _toDateTime(json['expires_at']),
      createdAt: _toDateTime(json['created_at']),
      updatedAt: _toDateTime(json['updated_at']),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      items:
          itemsRaw
              ?.map(
                (e) =>
                    AdminCartItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const <AdminCartItem>[],
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
