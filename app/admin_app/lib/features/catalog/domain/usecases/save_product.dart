import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/catalog/product_repository.dart';

/// ينشئ المنتج حين لا يكون له معرّف بعد، ويحدّثه وإلا.
///
/// البطاقة لا تحمل حقل مخزون، فيبقى مخزون الفرع كما هو في القاعدة.
class SaveProductUseCase {
  const SaveProductUseCase(this._repository);

  final ProductRepository _repository;

  Future<AdminProduct> call(AdminProduct product, {String? branchId}) =>
      _repository.saveProduct(product, branchId: branchId);
}
