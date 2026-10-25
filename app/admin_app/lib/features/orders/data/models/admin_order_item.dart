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
    final preferred = language.isArabic ? productNameAr : productNameEn;
    final fallback = language.isArabic ? productNameEn : productNameAr;
    if (preferred?.trim().isNotEmpty == true) return preferred!.trim();
    if (fallback?.trim().isNotEmpty == true) return fallback!.trim();
    return 'Product';
  }

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) => AdminOrderItem(
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
