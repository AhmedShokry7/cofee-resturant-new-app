import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';

/// عقد ما يحتاجه مشروب واحد من الأحجام والإضافات: ما يسري عليه، وسعر كل خيار
/// لديه، وربط مجموعة به أو فصله.
///
/// لا يمت هذا العقد إلى `OptionGroupRepository` بصلة: ذاك يحرّر المجموعة كلها
/// من صفحتها، وهذا يقرأ جواب القاعدة لمشروب واحد ويكتب ما يغيّره. الفيتشر لا
/// يستورد فيتشرًا آخر، فشاشة المنتج تُفتح على هذا العقد وحده.
abstract interface class ProductOptionRepository {
  /// المجموعات النشطة كلها مع جواب 224 لهذا المشروب وأسعار 229 عنده.
  Future<List<AdminProductOptionGroup>> loadForProduct(String productId);

  /// يكتب زيادة خيار لهذا المشروب وحده؛ و`null` تمحو التجاوز فتُعمل زيادة
  /// المجموعة، وهو ما يعيده إلى ما قبل 229.
  Future<void> setValuePrice(String productId, String valueId, double? delta);

  /// يربط مجموعة بالمشروب أو يفصلها عنه، بالصفّ الذي يقرّره نطاق المجموعة.
  Future<void> setGroupAttached(
    String productId,
    String groupId,
    bool attached,
  );
}
