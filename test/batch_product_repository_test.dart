import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/batch_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';

void main() {
  test('uses the bulk product reader once for multiple ids', () async {
    final repository = _BatchCatalog();
    final products = await getProductsByIds(repository, const [
      'first',
      'second',
      'first',
    ]);

    expect(repository.batchCalls, 1);
    expect(repository.singleCalls, 0);
    expect(repository.receivedIds, ['first', 'second']);
    expect(products.map((product) => product.id), ['first', 'second']);
  });
}

class _BatchCatalog extends MockProductRepository
    implements BatchProductRepository {
  int batchCalls = 0;
  int singleCalls = 0;
  List<String> receivedIds = const [];

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    singleCalls++;
    return ProductModel(id: id, name: id, price: 1, image: '');
  }

  @override
  Future<List<ProductModel>> getByIds(
    List<String> ids, {
    String? branchId,
  }) async {
    batchCalls++;
    receivedIds = ids;
    return [
      for (final id in ids) ProductModel(id: id, name: id, price: 1, image: ''),
    ];
  }
}
