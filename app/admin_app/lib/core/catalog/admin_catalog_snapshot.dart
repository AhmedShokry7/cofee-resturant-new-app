import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';

/// الكتالوج الذي تعمل عليه لوحة التحكم: المنتجات والتصنيفات والفرع الذي تُراجع
/// مخازنه.
class AdminCatalogSnapshot {
  const AdminCatalogSnapshot({
    required this.products,
    required this.categories,
    this.branchId,
    this.total = 0,
  });

  final List<AdminProduct> products;
  final List<AdminCategory> categories;
  final String? branchId;

  /// عدد المنتجات المطابقة للاستعلام قبل قصّ الصفحة منها.
  final int total;
}
