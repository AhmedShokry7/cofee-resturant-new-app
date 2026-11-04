import 'package:admin_app/features/option_groups/data/repositories/admin_option_group_repository.dart';
import 'package:admin_app/features/option_groups/data/repositories/admin_product_option_repository.dart';
import 'package:admin_app/features/option_groups/domain/repositories/option_group_repository.dart';
import 'package:admin_app/features/option_groups/domain/repositories/product_option_repository.dart';

/// نقطة تركيب اعتمادات فيتشر مجموعات الخيارات داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class OptionGroupsDependencies {
  OptionGroupsDependencies._();

  static OptionGroupRepository? _repository;
  static ProductOptionRepository? _productRepository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static OptionGroupRepository get repository =>
      _repository ??= AdminOptionGroupRepository();

  /// عقد شاشة المنتج: ما يسري على مشروب واحد فقط.
  static ProductOptionRepository get productRepository =>
      _productRepository ??= AdminProductOptionRepository();
}
