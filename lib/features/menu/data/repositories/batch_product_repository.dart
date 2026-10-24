import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

/// Optional bulk-read capability for repositories that can resolve many
/// products with one database round trip (plus shared image/price lookups).
abstract interface class BatchProductRepository {
  Future<List<ProductModel>> getByIds(List<String> ids, {String? branchId});
}

/// Uses the bulk implementation when available. Small local/test repositories
/// retain a compatible fallback.
Future<List<ProductModel>> getProductsByIds(
  ProductRepository repository,
  List<String> ids, {
  String? branchId,
}) async {
  final uniqueIds = ids.toSet().toList(growable: false);
  if (uniqueIds.isEmpty) return const [];
  if (repository case final BatchProductRepository batchRepository) {
    return batchRepository.getByIds(uniqueIds, branchId: branchId);
  }
  final products = await Future.wait(
    uniqueIds.map((id) => repository.getById(id, branchId: branchId)),
  );
  return products.whereType<ProductModel>().toList(growable: false);
}
