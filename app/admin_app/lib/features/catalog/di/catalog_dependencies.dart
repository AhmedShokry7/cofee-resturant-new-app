import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الكتالوج داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class CatalogDependencies {
  CatalogDependencies._();

  static CatalogData? _catalog;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static CatalogData get catalog => _catalog ??= AdminProductRepository();
}
