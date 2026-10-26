import 'package:admin_app/core/catalog/branch_pricing_repository.dart';
import 'package:admin_app/core/catalog/catalog_repository.dart';
import 'package:admin_app/core/catalog/category_repository.dart';
import 'package:admin_app/core/catalog/product_image_repository.dart';
import 'package:admin_app/core/catalog/product_repository.dart';

/// الكتالوج كما تحتاجه الشاشات: عقود القراءة والكتابة معًا في نقطة وصول واحدة،
/// لمن يفتح نموذجًا يعمل على المنتجات والتصنيفات والأسعار معًا.
abstract interface class CatalogData
    implements
        CatalogRepository,
        ProductRepository,
        CategoryRepository,
        ProductImageRepository,
        BranchPricingRepository {}
