import 'package:admin_app/core/models/admin_product.dart';

/// كتابة بيانات المنتج وحالة التمييز والحذف.
abstract interface class ProductRepository {
  /// ينشئ المنتج حين لا يكون له معرّف بعد، ويحدّثه وإلا.
  ///
  /// البطاقة لا تحمل حقل مخزون، فيبقى مخزون الفرع كما هو في القاعدة.
  Future<AdminProduct> saveProduct(AdminProduct product, {String? branchId});

  Future<void> deleteProduct(String productId);

  Future<void> setFeatured(String productId, bool isFeatured);
}
