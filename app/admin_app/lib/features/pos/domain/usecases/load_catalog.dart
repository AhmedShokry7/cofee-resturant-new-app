import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';

/// قراءة كتالوج الكاشير للفرع المختار.
class LoadCatalogUseCase {
  const LoadCatalogUseCase(this._repository);

  final PosRepository _repository;

  Future<PosCatalog> call({String? branchId}) =>
      _repository.loadCatalog(branchId: branchId);
}
